module ApplicationHelper
  def sidebar_nav_link(label, path, match: :prefix, &block)
    active = case match
             when :exact   then request.path == URI.parse(path).path
             when :prefix  then request.path.start_with?(URI.parse(path).path)
             end

    base   = "flex items-center gap-3 px-3 py-2 text-sm font-medium rounded-lg transition-colors duration-150"
    active_cls   = "bg-teal-600 text-white"
    inactive_cls = "text-slate-300 hover:bg-slate-800 hover:text-white"

    link_to path, class: "#{base} #{active ? active_cls : inactive_cls}" do
      concat(capture(&block)) if block_given?
      concat(content_tag(:span, label))
    end
  end

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
