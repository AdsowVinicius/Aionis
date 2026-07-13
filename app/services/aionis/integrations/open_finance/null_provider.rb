# frozen_string_literal: true

module Aionis
  module Integrations
    module OpenFinance
      # Provedor padrão sem integração real. Open Finance fica preparado mas
      # desligado no MVP (CLAUDE.md). Nenhuma chamada externa.
      class NullProvider < Base
        def create_consent(workspace_id:, redirect_url:)   = unavailable
        def fetch_accounts(consent_id:)                    = unavailable
        def fetch_transactions(account_id:, from:, to:)    = unavailable
        def revoke_consent(consent_id:)                    = unavailable
      end
    end
  end
end
