# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Envia uma OutgoingMessage via provider, com retries e backoff exponencial.
    # Toda saída passa por Aionis::Integrations.whatsapp(provider:) -> provider
    # concreto (Meta/Evolution), com as credenciais do canal. Rate limit/5xx da
    # Meta viram falha transitória (Result pending) e disparam novo retry.
    class SendMessageJob < ApplicationJob
      queue_as :default

      retry_on DeliveryError, attempts: 5, wait: :polynomially_longer do |job, error|
        outgoing = OutgoingMessage.find_by(id: job.arguments.first)
        if outgoing
          outgoing.mark_failed!(error.message)
          AuditLog.log(
            action: "integration", origin: "integration",
            workspace: outgoing.workspace, provider: outgoing.workspace_channel.provider,
            reason: "Envio WhatsApp falhou após retries: #{error.message}",
            metadata: { outgoing_message_id: outgoing.id, attempts: outgoing.attempts }
          )
        end
      end

      def perform(outgoing_id)
        outgoing = OutgoingMessage.find_by(id: outgoing_id)
        return unless outgoing&.pending?

        channel = outgoing.workspace_channel
        outgoing.increment!(:attempts)

        result = Aionis::Integrations.whatsapp(provider: channel.provider).send_text(
          to:          outgoing.to_number,
          body:        outgoing.body,
          instance:    channel.instance,
          credentials: channel.credentials
        )

        if result.success?
          outgoing.mark_sent!(result.data["message_id"])
          AuditLog.log(
            action: "integration", origin: "integration",
            workspace: outgoing.workspace, provider: channel.provider,
            reason: "Mensagem WhatsApp enviada",
            metadata: { outgoing_message_id: outgoing.id, to: outgoing.to_number }
          )
        else
          # Result pending (429/5xx) ou error → retry com backoff.
          raise DeliveryError, (result.message.presence || "Falha ao enviar mensagem")
        end
      end
    end
  end
end
