# frozen_string_literal: true

require "set"

module Aionis
  module OpenFinance
    # Concilia uma BankTransaction com um FinancialTransaction do workspace.
    #
    # Score (0..100): valor idêntico (55) + proximidade de data (0..30) +
    # semelhança de descrição (15). Faixas:
    #   >= 85  conciliação automática (match confirmado)
    #   60-84  sugestão (requer confirmação do usuário)
    #   < 60   sem match
    class Reconciler
      AUTO_CONFIRM_MIN = 85
      SUGGEST_MIN      = 60
      DATE_WINDOW      = 5 # dias

      STOPWORDS = %w[de da do das dos com para por pix ted doc pagamento compra
                     conta valor ref referente transferencia deposito debito credito].to_set.freeze

      def self.call(bank_transaction) = new(bank_transaction).call

      def initialize(bank_transaction)
        @bt        = bank_transaction
        @workspace = bank_transaction.workspace
      end

      def call
        return if @bt.matched? || @bt.ignored?

        ft, score, reasons = best_candidate
        return if ft.nil? || score < SUGGEST_MIN

        create_match(ft, score, reasons)
      end

      private

      def best_candidate
        best = nil
        candidates.each do |ft|
          score, reasons = score_for(ft)
          best = [ft, score, reasons] if best.nil? || score > best[1]
        end
        best
      end

      def candidates
        scope = @workspace.financial_transactions
                          .where(kind: @bt.financial_kind, amount_cents: @bt.amount_cents)
                          .where.not(id: confirmed_ft_ids)
        if @bt.posted_on
          scope = scope.where(transacted_on: (@bt.posted_on - DATE_WINDOW)..(@bt.posted_on + DATE_WINDOW))
        end
        scope.to_a
      end

      def confirmed_ft_ids
        ReconciliationMatch.where(workspace_id: @workspace.id, status: "confirmed")
                           .select(:financial_transaction_id)
      end

      def score_for(ft)
        score   = 55 # valor idêntico (filtro de candidato garante)
        reasons = ["valor idêntico"]

        if (days = date_distance(ft))
          case days
          when 0    then score += 30; reasons << "mesma data"
          when 1..2 then score += 22; reasons << "data próxima"
          when 3..5 then score += 12; reasons << "data aproximada"
          end
        end

        if description_overlap?(ft)
          score += 15
          reasons << "descrição semelhante"
        end

        [[score, 100].min, reasons]
      end

      def date_distance(ft)
        return nil unless ft.transacted_on && @bt.posted_on
        (ft.transacted_on - @bt.posted_on).abs.to_i
      end

      def description_overlap?(ft)
        bank_tokens  = tokens(@bt.description)
        ft_tokens    = tokens("#{ft.description} #{ft.counterparty_name_snapshot}")
        (bank_tokens & ft_tokens).any?
      end

      def tokens(text)
        I18n.transliterate(text.to_s.downcase)
            .split(/[^a-z0-9]+/)
            .reject { |t| t.length < 4 || STOPWORDS.include?(t) }
            .to_set
      end

      def create_match(ft, score, reasons)
        status = score >= AUTO_CONFIRM_MIN ? "confirmed" : "suggested"

        match = @workspace.reconciliation_matches.create!(
          bank_transaction:      @bt,
          financial_transaction: ft,
          score:                 score,
          status:                status,
          matched_by:            "system",
          reasons:               reasons
        )

        if status == "confirmed"
          @bt.update!(reconciliation_status: "matched", financial_transaction: ft)
          audit(match, ft)
        end

        match
      end

      def audit(match, ft)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @workspace, provider: "open_finance",
          financial_transaction: ft,
          confidence: match.score,
          reason: "Conciliação bancária automática",
          metadata: { bank_transaction_id: @bt.id, score: match.score, reasons: match.reasons }
        )
      end
    end
  end
end
