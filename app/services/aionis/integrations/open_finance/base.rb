# frozen_string_literal: true

module Aionis
  module Integrations
    module OpenFinance
      # Contrato de um provedor de Open Finance (agregador bancário).
      # Preparado para o futuro — NÃO implementado no MVP (CLAUDE.md seção 3/5).
      class Base < BaseProvider
        # Inicia um consentimento de acesso aos dados bancários.
        # @return [Result] data: { consent_id:, redirect_url:, expires_at: }
        def create_consent(workspace_id:, redirect_url:)
          not_implemented!(:create_consent)
        end

        # Lista contas autorizadas por um consentimento.
        # @return [Result] data: { accounts: [ { id:, name:, branch:, number:, kind: } ] }
        def fetch_accounts(consent_id:)
          not_implemented!(:fetch_accounts)
        end

        # Busca transações bancárias de uma conta em um período.
        # @return [Result] data: { transactions: [ { id:, amount_cents:, date:, description: } ] }
        def fetch_transactions(account_id:, from:, to:)
          not_implemented!(:fetch_transactions)
        end

        # Revoga um consentimento.
        # @return [Result]
        def revoke_consent(consent_id:)
          not_implemented!(:revoke_consent)
        end
      end
    end
  end
end
