# frozen_string_literal: true

module Aionis
  module Whatsapp
    # Conecta um WhatsApp Business a um workspace e faz rotação de credenciais.
    # Regra de negócio fora do controller. Segredos (access_token/refresh_token)
    # são gravados criptografados pelo model. Auditado.
    class ChannelConnector
      META_ATTRS = %i[phone_number_id business_account_id display_phone_number
                      access_token refresh_token verify_token webhook_secret].freeze

      def self.connect(workspace, provider: "meta_cloud", **attrs)
        new(workspace).connect(provider: provider, **attrs)
      end

      def initialize(workspace)
        @workspace = workspace
      end

      def connect(provider:, **attrs)
        channel = find_channel(provider, attrs)
        channel.assign_attributes(attrs.slice(*META_ATTRS))
        channel.provider = provider
        channel.status   = "connected"
        channel.active   = true
        channel.instance = attrs[:instance] if attrs[:instance].present?
        channel.save!
        audit(channel, "Canal WhatsApp conectado")
        channel
      end

      def rotate(channel, access_token:, refresh_token: nil)
        channel.access_token = access_token
        channel.refresh_token = refresh_token if refresh_token
        channel.save!
        audit(channel, "Credenciais do canal rotacionadas")
        channel
      end

      private

      def find_channel(provider, attrs)
        if provider == "meta_cloud" && attrs[:phone_number_id].present?
          @workspace.workspace_channels.find_or_initialize_by(phone_number_id: attrs[:phone_number_id])
        elsif attrs[:instance].present?
          @workspace.workspace_channels.find_or_initialize_by(instance: attrs[:instance])
        else
          @workspace.workspace_channels.new
        end
      end

      def audit(channel, reason)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @workspace, provider: channel.provider, reason: reason,
          metadata: { workspace_channel_id: channel.id, phone_number_id: channel.phone_number_id }
        )
      end
    end
  end
end
