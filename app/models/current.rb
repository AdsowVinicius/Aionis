# Contexto por requisição/thread (ActiveSupport::CurrentAttributes).
#
# Preenchido no ApplicationController (usuário) e no Workspaces::BaseController
# (workspace). Lido pela auditoria (concern Auditable / AuditLog) para saber
# QUEM fez a operação sem acoplar os models ao controller.
#
# Em jobs/tarefas de fundo não há requisição: os atributos ficam nil e a
# auditoria trata a operação como originada pelo sistema.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :workspace

  # Anotação da operação em andamento (action/reason/provider/confidence/...).
  # Usada por AuditLog.annotate para enriquecer o log automático do save atual.
  attribute :audit_annotation
end
