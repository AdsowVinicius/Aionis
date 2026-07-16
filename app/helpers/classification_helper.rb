module ClassificationHelper
  COST_TYPE_LABELS = {
    "fixed"         => "Custo fixo",
    "variable"      => "Custo variável",
    "semi_variable" => "Custo semivariável",
    "one_time"      => "Custo pontual"
  }.freeze

  ESSENTIALITY_LABELS = {
    "essential"             => "Essencial",
    "operational_important" => "Importante operacional",
    "non_essential"         => "Não essencial",
    "superfluous"           => "Supérfluo",
    "review"                => "Revisar"
  }.freeze

  SCOPE_LABELS = {
    "personal" => "Pessoal",
    "business" => "Empresarial",
    "mixed"    => "Misto",
    "review"   => "Revisar"
  }.freeze

  RECURRENCE_LABELS = {
    "recurring"  => "Recorrente",
    "occasional" => "Ocasional",
    "one_off"    => "Pontual"
  }.freeze

  def cost_type_label(value)     = COST_TYPE_LABELS[value] || value
  def essentiality_label(value)  = ESSENTIALITY_LABELS[value] || value
  def scope_label(value)         = SCOPE_LABELS[value] || value
  def recurrence_label(value)    = RECURRENCE_LABELS[value] || value

  def classification_source_label(source)
    {
      "rule"         => "Regra de classificação",
      "rule+history" => "Regra + histórico",
      "history"      => "Histórico do fornecedor",
      "manual"       => "Definido manualmente",
      "none"         => "Sem classificação automática"
    }[source] || source
  end

  RULE_ORIGIN_LABELS = {
    "seed"    => "Sistema",
    "manual"  => "Manual",
    "learned" => "Aprendida"
  }.freeze

  def rule_origin_label(origin) = RULE_ORIGIN_LABELS[origin] || origin

  # Natureza da regra → rótulo ("" = qualquer)
  def rule_kind_label(kind)
    { "income" => "Receita", "expense" => "Despesa" }[kind.to_s.presence] || "Qualquer"
  end

  # Badge de origem da regra → classes de estilo
  def rule_origin_badge(rule)
    label = rule_origin_label(rule.origin)
    classes =
      case rule.origin
      when "seed"    then "bg-slate-100 text-slate-600 border-slate-200"
      when "manual"  then "bg-teal-50 text-teal-700 border-teal-200"
      when "learned" then "bg-indigo-50 text-indigo-700 border-indigo-200"
      else                "bg-slate-100 text-slate-600 border-slate-200"
      end
    content_tag :span, label,
                class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border #{classes}"
  end

  # Descrição legível da condição de casamento de uma regra
  def rule_condition_summary(rule)
    parts = []
    parts << "Palavras: #{rule.keywords}"                     if rule.keywords.present?
    parts << "CPF/CNPJ: #{rule.tax_id}"                       if rule.tax_id.present?
    parts << "Fornecedor: #{rule.counterparty&.name}"         if rule.counterparty_id.present?
    parts.presence&.join(" · ") || "Sem condição"
  end

  # Faixa de confiança conforme CLAUDE.md → [rótulo, classes de badge]
  def confidence_tier(score)
    case score.to_i
    when 86..100 then ["Alta", "bg-emerald-50 text-emerald-700 border-emerald-200"]
    when 61..85  then ["Média", "bg-amber-50 text-amber-700 border-amber-200"]
    else              ["Baixa", "bg-slate-100 text-slate-600 border-slate-200"]
    end
  end
end
