module ApplicationHelper
  # Item de navegação da sidebar navy (AppShell do Figma):
  # ativo = bg-teal sólido; inativo = texto claro com hover sutil.
  def sidebar_nav_link(label, path, match: :prefix, &block)
    active = case match
    when :exact   then request.path == URI.parse(path).path
    when :prefix  then request.path.start_with?(URI.parse(path).path)
    end

    base   = "flex items-center gap-3 px-3 h-10 rounded-lg text-sm transition-colors duration-150"
    active_cls   = "bg-teal text-white"
    inactive_cls = "text-white/70 hover:bg-white/5 hover:text-white"

    link_to path, class: "#{base} #{active ? active_cls : inactive_cls}" do
      concat(capture(&block)) if block_given?
      concat(content_tag(:span, label))
    end
  end

  # Dados reais do card de plano da sidebar (nil quando não há assinatura).
  def sidebar_plan
    return @sidebar_plan if defined?(@sidebar_plan)
    plan = current_workspace&.subscription&.plan
    return @sidebar_plan = nil unless plan

    used  = current_workspace.documents.where(created_at: Time.current.all_month).count
    limit = plan.max_documents_month
    @sidebar_plan = { name: plan.name, used: used, limit: limit,
                      pct: limit.to_i.positive? ? [(used * 100.0 / limit).round, 100].min : 0 }
  end

  def workspace_kind_label(workspace)
    { "cpf" => "CPF", "mei" => "MEI", "empresa" => "Empresa" }[workspace&.kind] || ""
  end

  # Papel do usuário no workspace atual (topbar).
  def current_workspace_role
    return @current_workspace_role if defined?(@current_workspace_role)
    role = current_workspace && current_user &&
           current_workspace.workspace_users.find_by(user: current_user)&.role
    @current_workspace_role = { "owner" => "Admin", "admin" => "Admin",
                                "member" => "Membro" }[role] || role&.capitalize || "Membro"
  end

  def user_initials(user)
    user.name.to_s.split.map(&:first).join[0, 2].upcase.presence || "A"
  end

  # Sugestões do chat — apenas perguntas que as tools do agente respondem
  # de verdade (consultar_contas/gastos/kpis, gerar_insight). Nada inventado.
  CHAT_SUGGESTIONS = [
    "Quanto tenho para pagar essa semana?",
    "Qual foi meu maior gasto do mês?",
    "Meu caixa está saudável?",
    "Quanto gastei com combustível?",
    "Como estão meus indicadores do mês?",
    "Gerar um resumo financeiro do mês."
  ].freeze

  def chat_suggestions = CHAT_SUGGESTIONS

  def format_brl(cents)
    value = (cents || 0) / 100.0
    number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".", precision: 2)
  end

  TRANSACTION_STATUS_STYLES = {
    "pending"    => { label: "Pendente",     css: "bg-amber-50 text-amber-700 border border-amber-200" },
    "classified" => { label: "Classificado", css: "bg-blue-50 text-blue-700 border border-blue-200" },
    "confirmed"  => { label: "Confirmado",   css: "bg-teal-50 text-teal-700 border border-teal-200" },
    "cancelled"  => { label: "Cancelado",    css: "bg-slate-100 text-slate-500 border border-slate-200" }
  }.freeze

  def transaction_status_badge(status)
    style = TRANSACTION_STATUS_STYLES[status.to_s] || { label: status.to_s.humanize, css: "bg-slate-100 text-slate-500" }
    content_tag(:span, style[:label],
                class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{style[:css]}")
  end

  DOCUMENT_STATUS_STYLES = {
    "pending"    => { label: "Pendente",    css: "bg-amber-50 text-amber-700 border border-amber-200" },
    "processing" => { label: "Processando", css: "bg-blue-50 text-blue-700 border border-blue-200" },
    "processed"  => { label: "Processado",  css: "bg-teal-50 text-teal-700 border border-teal-200" },
    "failed"     => { label: "Com erro",    css: "bg-red-50 text-red-700 border border-red-200" },
    "review"     => { label: "Em revisão",  css: "bg-purple-50 text-purple-700 border border-purple-200" }
  }.freeze

  def document_status_badge(status)
    style = DOCUMENT_STATUS_STYLES[status.to_s] || { label: status.to_s.humanize, css: "bg-slate-100 text-slate-500" }
    content_tag(:span, style[:label],
                class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{style[:css]}")
  end

  def document_content_type_label(content_type)
    case content_type.to_s
    when "application/pdf"             then "PDF"
    when "image/jpeg"                  then "JPG"
    when "image/png"                   then "PNG"
    when "text/xml", "application/xml" then "XML"
    else content_type.to_s.split("/").last.upcase
    end
  end

  CATEGORY_KIND_LABELS = {
    "income"   => "Receita",
    "expense"  => "Despesa",
    "transfer" => "Transferência"
  }.freeze

  def category_kind_label(kind)
    CATEGORY_KIND_LABELS[kind.to_s] || kind.to_s
  end

  COST_TYPE_LABELS = {
    "fixed"         => "Fixo",
    "variable"      => "Variável",
    "semi_variable" => "Semivariável",
    "one_time"      => "Pontual"
  }.freeze

  def cost_type_label(cost_type)
    COST_TYPE_LABELS[cost_type.to_s] || "—"
  end

  ESSENTIALITY_LABELS = {
    "essential"              => "Essencial",
    "operational_important"  => "Importante operacional",
    "non_essential"          => "Não essencial",
    "superfluous"            => "Supérfluo",
    "review"                 => "Revisar"
  }.freeze

  def essentiality_label(essentiality)
    ESSENTIALITY_LABELS[essentiality.to_s] || "—"
  end

  def category_origin_badge(category)
    if category.workspace_id.nil?
      content_tag(:span, "Sistema",
                  class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600 border border-slate-200")
    else
      content_tag(:span, "Personalizada",
                  class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium bg-teal-50 text-teal-700 border border-teal-200")
    end
  end

  COUNTERPARTY_KIND_LABELS = {
    "supplier" => "Fornecedor",
    "client"   => "Cliente",
    "both"     => "Ambos"
  }.freeze

  def counterparty_kind_label(kind)
    COUNTERPARTY_KIND_LABELS[kind.to_s] || kind.to_s
  end

  TAX_ID_SOURCE_LABELS = {
    "user_input"    => "Manual",
    "ocr"           => "OCR",
    "xml"           => "XML",
    "bank_statement"=> "Extrato bancário",
    "ai"            => "IA",
    "import"        => "Importação"
  }.freeze

  def tax_id_source_label(source)
    TAX_ID_SOURCE_LABELS[source.to_s] || "—"
  end

  TAX_ID_STATUS_STYLES = {
    "not_informed" => { label: "Não informado", css: "bg-slate-100 text-slate-500 border border-slate-200" },
    "informed"     => { label: "Informado",     css: "bg-blue-50 text-blue-700 border border-blue-200" },
    "verified"     => { label: "Verificado",    css: "bg-teal-50 text-teal-700 border border-teal-200" },
    "invalid"      => { label: "Inválido",      css: "bg-red-50 text-red-700 border border-red-200" },
    "skipped"      => { label: "Pulado",        css: "bg-slate-100 text-slate-400 border border-slate-200" }
  }.freeze

  def tax_id_status_badge(status)
    style = TAX_ID_STATUS_STYLES[status.to_s] || { label: status.to_s.humanize, css: "bg-slate-100 text-slate-500" }
    content_tag(:span, style[:label],
                class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{style[:css]}")
  end

  EXTRACTION_STATUS_STYLES = {
    "pending"      => { label: "Pendente",    css: "bg-slate-100 text-slate-500 border border-slate-200" },
    "processing"   => { label: "Processando", css: "bg-blue-50 text-blue-700 border border-blue-200" },
    "extracted"    => { label: "Extraído",    css: "bg-teal-50 text-teal-700 border border-teal-200" },
    "needs_review" => { label: "Revisar",     css: "bg-amber-50 text-amber-700 border border-amber-200" },
    "failed"       => { label: "Falhou",      css: "bg-red-50 text-red-700 border border-red-200" }
  }.freeze

  def extraction_status_badge(status)
    style = EXTRACTION_STATUS_STYLES[status.to_s] || { label: status.to_s.humanize, css: "bg-slate-100 text-slate-500" }
    content_tag(:span, style[:label],
                class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{style[:css]}")
  end

  SETTLEMENT_STATUS_STYLES = {
    "open"      => { label: "Em aberto",  css: "bg-amber-50 text-amber-700 border border-amber-200" },
    "settled"   => { label: "Liquidado",  css: "bg-teal-50 text-teal-700 border border-teal-200" },
    "cancelled" => { label: "Cancelado",  css: "bg-slate-100 text-slate-500 border border-slate-200" }
  }.freeze

  def settlement_status_badge(status)
    style = SETTLEMENT_STATUS_STYLES[status.to_s] || { label: status.to_s.humanize, css: "bg-slate-100 text-slate-500" }
    content_tag(:span, style[:label],
                class: "inline-block px-2 py-0.5 rounded-full text-xs font-medium #{style[:css]}")
  end

  def workspace_critical_alerts_count
    return 0 unless current_workspace
    @_workspace_alerts_summary ||= (@alerts_summary || Workspaces::AlertsSummary.new(current_workspace))
    @_workspace_alerts_summary.critical_count
  end

  def alert_link_path(alert, workspace)
    case alert.kind
    when :overdue_payables, :payables_due_soon, :payables_due_7days
      workspace_payables_path(workspace)
    when :overdue_receivables, :receivables_due_soon, :receivables_due_7days
      workspace_receivables_path(workspace)
    when :failed_documents, :review_documents, :pending_documents
      workspace_documents_path(workspace)
    when :pending_transactions, :transactions_no_category, :transactions_no_counterparty
      workspace_financial_transactions_path(workspace)
    else
      workspace_dashboard_path(workspace)
    end
  end

  def format_file_size(bytes)
    return "—" if bytes.nil?
    if bytes >= 1.megabyte
      "#{(bytes / 1.megabyte.to_f).round(1)} MB"
    elsif bytes >= 1.kilobyte
      "#{(bytes / 1.kilobyte.to_f).round(0).to_i} KB"
    else
      "#{bytes} B"
    end
  end
end
