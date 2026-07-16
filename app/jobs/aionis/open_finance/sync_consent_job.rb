# frozen_string_literal: true

module Aionis
  module OpenFinance
    # Sincroniza um consentimento em background (contas + transações + conciliação).
    class SyncConsentJob < ApplicationJob
      queue_as :default

      def perform(consent_id)
        consent = Consent.find_by(id: consent_id)
        return unless consent

        Aionis::OpenFinance::SyncService.call(consent)
      end
    end
  end
end
