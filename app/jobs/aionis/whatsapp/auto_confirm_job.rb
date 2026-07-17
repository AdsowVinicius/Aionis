# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Último passo do pipeline WhatsApp: após o ProcessDocumentJob extrair e
    # classificar o documento, cria a FinancialTransaction conforme a confiança
    # e responde ao usuário. Disparado pelo ProcessDocumentJob para documentos
    # com source "whatsapp". Auditado.
    class AutoConfirmJob < ApplicationJob
      queue_as :default

      AUTO_CONFIRM_MIN = 86
      REVIEW_MIN       = 61

      def perform(document_id)
        document = Document.find_by(id: document_id)
        return unless document&.source == "whatsapp"

        @incoming = IncomingMessage.find_by(document_id: document.id)
        return unless @incoming
        @channel = @incoming.workspace_channel

        extraction = document.latest_extraction
        suggestion = extraction&.suggested_transaction_data || {}
        confidence = extraction&.confidence_score.to_i

        if suggestion["amount_cents"].blank? || confidence < REVIEW_MIN
          reply(:low_confidence)
        elsif confidence >= AUTO_CONFIRM_MIN
          tx = create_transaction(document, extraction, suggestion, status: "confirmed")
          audit("Lançamento confirmado automaticamente", transaction: tx)
          reply(:confirmed, tx)
        else
          tx = create_transaction(document, extraction, suggestion, status: "pending")
          audit("Lançamento pendente de revisão", transaction: tx)
          reply(:review, tx)
        end
      end

      private

      def create_transaction(document, extraction, suggestion, status:)
        tx = @channel.workspace.financial_transactions.new(
          origin:        "document",
          document:      document,
          kind:          suggestion["kind"].presence || "expense",
          description:   suggestion["description"].presence || "Comprovante via WhatsApp",
          amount_cents:  suggestion["amount_cents"],
          transacted_on: parse_date(suggestion["transacted_on"]) || Date.current,
          status:        status,
          counterparty_name_snapshot:   suggestion["counterparty_name_snapshot"],
          counterparty_tax_id_snapshot: suggestion["counterparty_tax_id_snapshot"],
          counterparty_tax_id_status:   suggestion["counterparty_tax_id_status"]
        )
        classification = Aionis::ClassificationEngine.for_transaction(tx, extra_text: extraction&.raw_text).call
        tx.apply_classification(classification, only_blank: true) if classification.present?
        tx.save!
        tx
      end

      def reply(kind, transaction = nil)
        Aionis::Whatsapp::Responder.reply(incoming: @incoming, kind: kind, transaction: transaction)
      end

      def audit(reason, transaction:)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @channel.workspace, provider: @channel.provider,
          financial_transaction: transaction, document: transaction.document,
          reason: reason, metadata: { incoming_message_id: @incoming.id }
        )
      end

      def parse_date(str) = (Date.parse(str.to_s) rescue nil)
    end
  end
end
