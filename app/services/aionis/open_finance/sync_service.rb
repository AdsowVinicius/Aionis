# frozen_string_literal: true

module Aionis
  module OpenFinance
    # Sincroniza contas e transações bancárias de um consentimento ativo e
    # dispara a conciliação. Toda comunicação passa por
    # Aionis::Integrations.open_finance. Idempotente (upsert por external_id).
    class SyncService
      LOOKBACK_DAYS = 90

      def self.call(consent) = new(consent).call

      def initialize(consent)
        @consent   = consent
        @workspace = consent.workspace
      end

      def call
        return empty unless @consent.active? && @consent.external_id.present?

        accounts = sync_accounts
        tx_count = accounts.sum { |account| sync_transactions(account) }

        @consent.update!(last_synced_at: Time.current)
        audit(accounts.size, tx_count)
        { accounts: accounts.size, transactions: tx_count }
      end

      private

      def sync_accounts
        result = provider.fetch_accounts(consent_id: @consent.external_id)
        return [] unless result.success?

        Array(result.data["accounts"]).map do |attrs|
          account = @consent.bank_accounts.find_or_initialize_by(external_id: attrs["external_id"])
          account.assign_attributes(
            workspace:      @workspace,
            name:           attrs["name"],
            institution:    attrs["institution"],
            branch:         attrs["branch"],
            number:         attrs["number"],
            kind:           attrs["kind"],
            currency:       attrs["currency"].presence || "BRL",
            balance_cents:  attrs["balance_cents"],
            last_synced_at: Time.current
          )
          account.save!
          account
        end
      end

      def sync_transactions(account)
        result = provider.fetch_transactions(
          account_id: account.external_id,
          from:       LOOKBACK_DAYS.days.ago.to_date.iso8601,
          to:         Date.current.iso8601
        )
        return 0 unless result.success?

        new_count = 0
        Array(result.data["transactions"]).each do |attrs|
          bt = account.bank_transactions.find_or_initialize_by(external_id: attrs["external_id"])
          next unless bt.new_record?

          bt.assign_attributes(
            workspace:    @workspace,
            amount_cents: attrs["amount_cents"],
            direction:    attrs["direction"],
            posted_on:    parse_date(attrs["date"]),
            description:  attrs["description"],
            raw:          attrs["raw"] || {}
          )
          bt.save!
          new_count += 1
          Aionis::OpenFinance::Reconciler.call(bt)
        end
        new_count
      end

      def provider = Aionis::Integrations.open_finance

      def audit(accounts, transactions)
        AuditLog.log(
          action: "integration", origin: "integration",
          workspace: @workspace, provider: @consent.provider,
          reason: "Sincronização Open Finance",
          metadata: { consent_id: @consent.id, accounts: accounts, transactions: transactions }
        )
      end

      def parse_date(str) = (Date.parse(str.to_s) rescue nil)
      def empty           = { accounts: 0, transactions: 0 }
    end
  end
end
