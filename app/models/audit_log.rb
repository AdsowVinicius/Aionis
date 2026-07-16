# Registro de auditoria imutável de operações importantes do Aionis.
#
# Duas formas de gerar logs:
#   1. Automática — models que incluem `Auditable` logam create/update/destroy.
#   2. Explícita  — eventos de domínio (classificação, processamento, OCR, IA,
#      integrações) via `AuditLog.record!` ou anotando o save com
#      `AuditLog.annotate`.
#
#   AuditLog.record!(action: "document_processing", origin: "job",
#                    workspace: ws, document: doc, provider: "fiscal_xml",
#                    confidence: 92, metadata: { ... })
#
#   AuditLog.annotate(action: "reclassify", reason: "Categoria trocada") do
#     transaction.save
#   end
#
# Nunca deve quebrar o fluxo principal: os pontos automáticos usam `AuditLog.log`
# (resiliente). O registro é imutável após criado.
class AuditLog < ApplicationRecord
  # workspace_id/user_id/etc. são bigint sem FK (histórico sobrevive à exclusão
  # da entidade), por isso todas as associações são opcionais.
  belongs_to :workspace,             optional: true
  belongs_to :user,                  optional: true
  belongs_to :document,              optional: true
  belongs_to :financial_transaction, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  ACTIONS = %w[
    create update destroy
    auto_classify reclassify confirm rule_execution
    document_processing ocr ai integration
  ].freeze

  ORIGINS = %w[user system job rule ocr ai integration].freeze

  # Colunas que nunca entram no diff before/after
  IGNORED_ATTRIBUTES = %w[created_at updated_at].freeze

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :confidence, numericality: { in: 0..100 }, allow_nil: true

  # Imutável: permite criar e destruir (limpeza), nunca atualizar.
  before_update { raise ActiveRecord::ReadOnlyRecord, "AuditLog é imutável" }

  scope :recent,        -> { order(created_at: :desc, id: :desc) }
  scope :in_workspace,  ->(ws) { where(workspace_id: ws) }
  scope :with_action,   ->(a)  { where(action: a) }
  scope :with_origin,   ->(o)  { where(origin: o) }
  scope :for_auditable, ->(rec) { where(auditable_type: rec.class.name, auditable_id: rec.id) }

  class << self
    # Criador de baixo nível — levanta em caso de erro (use em testes/asserts).
    def record!(action:, origin: nil, workspace: nil, user: nil, document: nil,
                financial_transaction: nil, auditable: nil, reason: nil, provider: nil,
                confidence: nil, before: {}, after: {}, metadata: {}, summary: nil)
      create!(
        action:                action.to_s,
        origin:                (origin || default_origin).to_s,
        workspace:             workspace || auditable_workspace(auditable),
        user:                  user,
        document:              document,
        financial_transaction: financial_transaction,
        auditable:             auditable,
        reason:                reason,
        provider:              provider,
        confidence:            confidence,
        before_data:           sanitize(before),
        after_data:            sanitize(after),
        metadata:              sanitize(metadata),
        summary:               summary
      )
    end

    # Versão resiliente — nunca propaga erro (auditoria não pode quebrar o app).
    def log(**attrs)
      record!(**attrs)
    rescue => e
      Rails.logger.error("[AuditLog] falha ao registrar: #{e.class}: #{e.message}")
      nil
    end

    # Loga uma mutação de model (chamado pelo concern Auditable). Mescla a
    # anotação da operação atual (Current.audit_annotation), quando houver.
    def track(model, default_action)
      return if model.nil?

      note    = (Current.audit_annotation || {}).symbolize_keys
      diff    = diff_for(model, default_action)
      action  = (note[:action] || default_action).to_s

      # Ignora updates sem mudança real (ex.: apenas touch de updated_at).
      return if default_action.to_s == "update" && diff[:before].blank? && note[:action].blank?

      log(
        action:                action,
        origin:                note[:origin] || default_origin,
        workspace:             note[:workspace] || model.try(:workspace),
        user:                  note.key?(:user) ? note[:user] : Current.user,
        document:              note[:document]              || (model if model.is_a?(Document)),
        financial_transaction: note[:financial_transaction] || (model if model.is_a?(FinancialTransaction)),
        auditable:             model,
        reason:                note[:reason],
        provider:              note[:provider],
        confidence:            note[:confidence],
        before:                diff[:before],
        after:                 diff[:after],
        metadata:              note[:metadata] || {},
        summary:               note[:summary] || default_summary(model, action)
      )
    end

    # Anota a operação em andamento; a próxima gravação do concern usa estes
    # campos. Sempre restaura o contexto ao fim do bloco.
    def annotate(**context)
      previous = Current.audit_annotation
      Current.audit_annotation = (previous || {}).merge(context)
      yield
    ensure
      Current.audit_annotation = previous
    end

    def default_origin
      Current.user ? "user" : "system"
    end

    private

    def auditable_workspace(auditable)
      auditable.respond_to?(:workspace) ? auditable.workspace : nil
    end

    # before/after a partir do estado do model conforme a ação.
    def diff_for(model, action)
      case action.to_s
      when "create"
        { before: {}, after: attributes_snapshot(model) }
      when "destroy"
        { before: attributes_snapshot(model), after: {} }
      else # update e variações (reclassify/confirm)
        before = {}
        after  = {}
        model.saved_changes.except(*IGNORED_ATTRIBUTES).each do |attr, (old_v, new_v)|
          before[attr] = jsonable(old_v)
          after[attr]  = jsonable(new_v)
        end
        { before: before, after: after }
      end
    end

    def attributes_snapshot(model)
      model.attributes.except(*IGNORED_ATTRIBUTES).transform_values { |v| jsonable(v) }
    end

    def default_summary(model, action)
      "#{action} · #{model.class.model_name.human}: #{describe(model)}"
    end

    def describe(model)
      %i[name description title].each do |attr|
        return model.public_send(attr) if model.respond_to?(attr) && model.public_send(attr).present?
      end
      "##{model.id}"
    end

    # JSONB exige valores serializáveis (Date/Time -> ISO8601).
    def sanitize(hash)
      (hash || {}).deep_stringify_keys.transform_values { |v| jsonable(v) }
    end

    def jsonable(value)
      case value
      when Date, Time, DateTime, ActiveSupport::TimeWithZone then value.iso8601
      when BigDecimal then value.to_s("F")
      else value
      end
    end
  end
end
