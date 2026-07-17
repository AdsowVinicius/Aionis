# frozen_string_literal: true

module Aionis
  module OpenFinance
    # Confirmação/rejeição manual de uma sugestão de conciliação
    # (ReconciliationMatch). Regra fora do controller; audita cada decisão.
    class ReconciliationReview
      def self.confirm(match) = new(match).confirm
      def self.reject(match)  = new(match).reject

      def initialize(match)
        @match = match
      end

      def confirm
        @match.update!(status: "confirmed", matched_by: "user")
        @match.bank_transaction.update!(
          reconciliation_status: "matched",
          financial_transaction: @match.financial_transaction
        )
        audit("Conciliação confirmada pelo usuário")
        @match
      end

      def reject
        @match.update!(status: "rejected", matched_by: "user")
        bt = @match.bank_transaction
        # Se a transação estava conciliada por ESTA sugestão, volta a pendente.
        if bt.financial_transaction_id == @match.financial_transaction_id
          bt.update!(reconciliation_status: "pending", financial_transaction: nil)
        end
        audit("Conciliação rejeitada pelo usuário")
        @match
      end

      private

      def audit(reason)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @match.workspace, provider: "open_finance",
          financial_transaction: @match.financial_transaction,
          confidence: @match.score,
          reason: reason,
          metadata: {
            reconciliation_match_id: @match.id,
            bank_transaction_id: @match.bank_transaction_id, score: @match.score
          }
        )
      end
    end
  end
end
