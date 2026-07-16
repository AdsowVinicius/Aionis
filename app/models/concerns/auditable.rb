# Registra automaticamente create/update/destroy do model em AuditLog.
#
# Loga de forma síncrona (mesma transação da mudança), lendo o contexto de
# Current (usuário/workspace) e a anotação da operação atual (AuditLog.annotate)
# para enriquecer o log. Assim a anotação está garantidamente presente no
# momento do registro. Resiliente: AuditLog.track nunca propaga erro.
#
#   class Counterparty < ApplicationRecord
#     include Auditable
#   end
module Auditable
  extend ActiveSupport::Concern

  included do
    after_create  { AuditLog.track(self, :create) }
    after_update  { AuditLog.track(self, :update) }
    after_destroy { AuditLog.track(self, :destroy) }
  end
end
