# frozen_string_literal: true

module Aionis
  module Agent
    # Roda o Agente Financeiro para uma mensagem de TEXTO do WhatsApp — fora da
    # requisição web (loop de tool calling é lento). A resposta sai pelo mesmo
    # caminho das demais (Responder -> SendMessageJob), respeitando o dry-run.
    # Mídia NUNCA passa por aqui: segue no pipeline de OCR (DownloadMediaJob).
    class WhatsappReplyJob < ApplicationJob
      queue_as :default

      def perform(incoming_id)
        incoming = IncomingMessage.find_by(id: incoming_id)
        return unless incoming

        reply = Conversation.call(
          workspace: incoming.workspace,
          message:   incoming.text.to_s,
          channel:   "whatsapp"
        )

        Aionis::Whatsapp::Responder.reply_custom(incoming: incoming, body: reply.text)
        incoming.processed!
      rescue => e
        Rails.logger.error("[Agent::WhatsappReplyJob] #{e.class}: #{e.message}")
        Aionis::Whatsapp::Responder.reply(incoming: incoming, kind: :help) if incoming
        incoming&.processed!
      end
    end
  end
end
