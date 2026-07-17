# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Atualiza o status de entrega de uma OutgoingMessage a partir de um callback
    # de status da Meta (sent/delivered/read/failed). Auditado.
    class StatusUpdater
      def self.call(data) = new(data).call

      def initialize(data)
        @data = data
      end

      def call
        message_id = @data["wa_message_id"]
        status     = @data["status"]
        return if message_id.blank? || status.blank?

        outgoing = OutgoingMessage.find_by(provider_message_id: message_id)
        return unless outgoing

        status == "failed" ? outgoing.mark_failed!("Meta: falha na entrega") : outgoing.mark_status!(status)

        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: outgoing.workspace, provider: outgoing.workspace_channel.provider,
          reason: "Status de mensagem: #{status}",
          metadata: { outgoing_message_id: outgoing.id, provider_message_id: message_id, status: status }
        )
        outgoing
      end
    end
  end
end
