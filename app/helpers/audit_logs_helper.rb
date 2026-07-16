module AuditLogsHelper
  ACTION_LABELS = {
    "create"              => "Criação",
    "update"              => "Edição",
    "destroy"             => "Exclusão",
    "auto_classify"       => "Classificação automática",
    "reclassify"          => "Reclassificação manual",
    "confirm"             => "Confirmação",
    "rule_execution"      => "Execução de regra",
    "document_processing" => "Processamento de documento",
    "ocr"                 => "OCR",
    "ai"                  => "IA",
    "integration"         => "Integração externa"
  }.freeze

  ORIGIN_LABELS = {
    "user"        => "Usuário",
    "system"      => "Sistema",
    "job"         => "Processo",
    "rule"        => "Regra",
    "ocr"         => "OCR",
    "ai"          => "IA",
    "integration" => "Integração"
  }.freeze

  # Cor do badge por família de ação.
  ACTION_STYLES = {
    "create"              => "bg-emerald-50 text-emerald-700 border-emerald-200",
    "update"              => "bg-blue-50 text-blue-700 border-blue-200",
    "reclassify"          => "bg-blue-50 text-blue-700 border-blue-200",
    "confirm"             => "bg-teal-50 text-teal-700 border-teal-200",
    "destroy"             => "bg-red-50 text-red-700 border-red-200",
    "auto_classify"       => "bg-indigo-50 text-indigo-700 border-indigo-200",
    "rule_execution"      => "bg-indigo-50 text-indigo-700 border-indigo-200",
    "document_processing" => "bg-purple-50 text-purple-700 border-purple-200",
    "ocr"                 => "bg-purple-50 text-purple-700 border-purple-200",
    "ai"                  => "bg-purple-50 text-purple-700 border-purple-200",
    "integration"         => "bg-amber-50 text-amber-700 border-amber-200"
  }.freeze

  def audit_action_label(action) = ACTION_LABELS[action] || action.to_s.humanize
  def audit_origin_label(origin) = ORIGIN_LABELS[origin] || origin.to_s.humanize

  def audit_action_badge(action)
    css = ACTION_STYLES[action] || "bg-slate-100 text-slate-600 border-slate-200"
    content_tag :span, audit_action_label(action),
                class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border #{css}"
  end

  # Nome legível da entidade auditada (traduz o tipo do model).
  def audit_entity_label(log)
    return "—" if log.auditable_type.blank?

    human = log.auditable_type.constantize.model_name.human rescue log.auditable_type
    "#{human} ##{log.auditable_id}"
  end

  def audit_actor_label(log)
    return log.user.name if log.user
    audit_origin_label(log.origin)
  end
end
