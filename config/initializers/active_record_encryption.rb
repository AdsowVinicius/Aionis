# frozen_string_literal: true

# Chaves de criptografia do ActiveRecord (usadas por `encrypts` em
# WorkspaceChannel#access_token/#refresh_token). Segredos SÓ via ENV em produção
# (CLAUDE.md §9). Os defaults abaixo servem apenas a dev/test e DEVEM ser
# sobrescritos em produção via ENV — gere com `bin/rails db:encryption:init`.
Rails.application.config.active_record.encryption.tap do |enc|
  enc.primary_key         = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY",
                                       "aionis_dev_primary_key_change_me_in_production_please")
  enc.deterministic_key   = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY",
                                       "aionis_dev_deterministic_key_change_me_in_production")
  enc.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT",
                                       "aionis_dev_key_derivation_salt_change_me_in_prod_ok")
  enc.support_unencrypted_data = true # mantém compatibilidade com dados legados
end
