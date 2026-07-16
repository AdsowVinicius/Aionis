# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Envia uma OutgoingMessage via provider, com retries. Toda saída passa por
    # Aionis::Integrations.whatsapp -> provider concreto (Evolution).
    class SendMessageJob < ApplicationJob
      queue_as :default

      # Reenvia em falha de entrega; após esgotar as tentativas, marca falha.
      retry_on DeliveryError, attempts: 3, wait: :polynomially_longer do |job, error|
        outgoing = OutgoingMessage.find_by(id: job.arguments.first)
        outgoing&.mark_failed!(error.message)
      end

      def perform(outgoing_id)
        outgoing = OutgoingMessage.find_by(id: outgoing_id)
        return unless outgoing&.pending?

        outgoing.increment!(:attempts)

        result = Aionis::Integrations.whatsapp.send_text(
          to:       outgoing.to_number,
          body:     outgoing.body,
          instance: outgoing.workspace_channel.instance
        )

        if result.success?
          outgoing.mark_sent!(result.data["message_id"])
          AuditLog.log(
            action: "integration", origin: "integration",
            workspace: outgoing.workspace, provider: outgoing.workspace_channel.provider,
            reason: "Mensagem WhatsApp enviada",
            metadata: { outgoing_message_id: outgoing.id, to: outgoing.to_number }
          )
        else
          raise DeliveryError, (result.message.presence || "Falha ao enviar mensagem")
        end
      end
    end
  end
end
