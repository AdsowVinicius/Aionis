# frozen_string_literal: true

module Aionis
  module OpenFinance
    # Consentimento Open Finance: criação, ativação e revogação.
    # Toda comunicação passa por Aionis::Integrations.open_finance (o app não
    # conhece Pluggy/Belvo/Quanto). Registra AuditLog em cada passo.
    class ConsentService
      def self.create(workspace, redirect_url: nil) = new(workspace).create(redirect_url: redirect_url)

      def initialize(workspace)
        @workspace = workspace
      end

      # Inicia o consentimento (o widget do provedor cria a conexão/item).
      def create(redirect_url: nil)
        result = provider.create_consent(workspace_id: @workspace.id, redirect_url: redirect_url)
        return nil unless result.success?

        consent = @workspace.consents.create!(
          provider:      provider_key,
          status:        "pending",
          connect_token: result.data["connect_token"],
          redirect_url:  result.data["redirect_url"],
          expires_at:    parse_time(result.data["expires_at"])
        )
        audit(consent, "Consentimento iniciado")
        consent
      end

      # Ativa o consentimento com o item retornado pelo provedor (webhook/callback).
      def activate(consent, external_id:)
        consent.update!(external_id: external_id, status: "active")
        audit(consent, "Consentimento ativado")
        consent
      end

      def revoke(consent)
        provider.revoke_consent(consent_id: consent.external_id) if consent.external_id.present?
        consent.update!(status: "revoked", revoked_at: Time.current)
        audit(consent, "Consentimento revogado")
        consent
      end

      private

      def provider     = Aionis::Integrations.open_finance
      def provider_key = provider.try(:provider_key) || "pluggy"

      def audit(consent, reason)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @workspace, provider: consent.provider, reason: reason,
          metadata: { consent_id: consent.id, external_id: consent.external_id, status: consent.status }
        )
      end

      def parse_time(str) = (Time.zone.parse(str.to_s) rescue nil)
    end
  end
end
