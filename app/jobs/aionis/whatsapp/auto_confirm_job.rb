# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Último passo do pipeline WhatsApp: após o ProcessDocumentJob extrair e
    # classificar o documento, cria a FinancialTransaction conforme a confiança
    # e responde ao usuário. Disparado pelo ProcessDocumentJob para documentos
    # com source "whatsapp". A construção do lançamento fica no service
    # compartilhado Aionis::Documents::TransactionBuilder (DRY). Auditado.
    class AutoConfirmJob < ApplicationJob
      queue_as :default

      def perform(document_id)
        document = Document.find_by(id: document_id)
        return unless document&.source == "whatsapp"

        @incoming = IncomingMessage.find_by(document_id: document.id)
        return unless @incoming
        @channel = @incoming.workspace_channel

        builder = Aionis::Documents::TransactionBuilder.new(document)
        tx = builder.build

        if tx.nil? || Aionis::Confidence.low?(builder.confidence)
          reply(:low_confidence)
        elsif Aionis::Confidence.high?(builder.confidence)
          tx.update!(status: "confirmed")
          audit("Lançamento confirmado automaticamente", transaction: tx)
          reply(:confirmed, tx)
        else
          tx.update!(status: "pending")
          audit("Lançamento pendente de revisão", transaction: tx)
          reply(:review, tx)
        end
      end

      private

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
    end
  end
end
