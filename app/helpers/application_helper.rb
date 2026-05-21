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
    number_to_currency(value, unit: "R$ ", separator: ",", delimiter: ".", precision: 2)
  end
end
