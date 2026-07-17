# frozen_string_literal: true

module Aionis
  module Documents
    # Constrói um FinancialTransaction a partir da última extração de um Document
    # (dados sugeridos + classificação via Rule Engine/IA). Fonte única usada
    # tanto pela confirmação automática do WhatsApp quanto pela tela de revisão
    # de OCR — evita duplicar o mapeamento extração → lançamento.
    #
    #   tx = Aionis::Documents::TransactionBuilder.build(document)   # não salvo
    #   tx.save! if tx
    class TransactionBuilder
      AUTO_CONFIRM_MIN = 86

      def self.build(document, status: nil) = new(document).build(status: status)

      def initialize(document)
        @document   = document
        @extraction = document.latest_extraction
      end

      # Retorna um FinancialTransaction NÃO salvo (com classificação aplicada),
      # ou nil quando não há valor para lançar.
      def build(status: nil)
        return nil if suggestion["amount_cents"].blank?

        tx = @document.workspace.financial_transactions.new(
          origin:        "document",
          document:      @document,
          kind:          suggestion["kind"].presence || "expense",
          description:   suggestion["description"].presence || default_description,
          amount_cents:  suggestion["amount_cents"],
          transacted_on: parse_date(suggestion["transacted_on"]) || Date.current,
          status:        status || default_status,
          counterparty_name_snapshot:   suggestion["counterparty_name_snapshot"],
          counterparty_tax_id_snapshot: suggestion["counterparty_tax_id_snapshot"],
          counterparty_tax_id_status:   suggestion["counterparty_tax_id_status"]
        )

        classification = Aionis::ClassificationEngine.for_transaction(tx, extra_text: @extraction&.raw_text).call
        tx.apply_classification(classification, only_blank: true) if classification.present?
        tx
      end

      def confidence = @extraction&.confidence_score.to_i

      private

      def suggestion = @suggestion ||= (@extraction&.suggested_transaction_data || {})

      def default_status
        confidence >= AUTO_CONFIRM_MIN ? "confirmed" : "pending"
      end

      def default_description
        @document.source == "whatsapp" ? "Comprovante via WhatsApp" : "Documento digitalizado"
      end

      def parse_date(str) = (Date.parse(str.to_s) rescue nil)
    end
  end
end
