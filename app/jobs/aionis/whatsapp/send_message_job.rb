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

        result = provider_for(channel).send_text(
          to:          outgoing.to_number,
          body:        outgoing.body,
          instance:    channel.instance,
          credentials: channel.credentials
        )

        if result.success?
          settle(outgoing, channel, result)
        else
          # Result pending (429/5xx) ou error → retry com backoff.
          raise DeliveryError, (result.message.presence || "Falha ao enviar mensagem")
        end
      end

      private

      # Em dry-run resolve o DryRunProvider (não chama a Meta); caso contrário, o
      # provider real do canal. A decisão fica no job — a Integration Layer segue
      # intacta (o DryRunProvider implementa o mesmo contrato Whatsapp::Base).
      def provider_for(channel)
        key = Aionis::Integrations.whatsapp_dry_run? ? "dry_run" : channel.provider
        Aionis::Integrations.whatsapp(provider: key)
      end

      # O status vem de QUEM respondeu (result.provider): "dry_run" não foi à Meta.
      def settle(outgoing, channel, result)
        dry_run = result.provider == "dry_run"
        dry_run ? outgoing.mark_dry_run!(result.data["message_id"])
                : outgoing.mark_sent!(result.data["message_id"])

        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: outgoing.workspace, provider: channel.provider,
          reason: dry_run ? "WhatsApp em dry-run — envio suprimido (não foi à Meta)" : "Mensagem WhatsApp enviada",
          metadata: { outgoing_message_id: outgoing.id, to: outgoing.to_number, dry_run: dry_run }
        )
      end
    end
  end
end
