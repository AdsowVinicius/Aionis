module WhatsappChannelsHelper
  CHANNEL_STATUS_STYLES = {
    "connected"    => { label: "Conectado",    css: "bg-teal-50 text-teal-700 border-teal-200" },
    "pending"      => { label: "Pendente",     css: "bg-amber-50 text-amber-700 border-amber-200" },
    "disconnected" => { label: "Desconectado", css: "bg-slate-100 text-slate-500 border-slate-200" }
  }.freeze

  def whatsapp_channel_status_badge(channel)
    style = CHANNEL_STATUS_STYLES[channel.status.to_s] ||
            { label: channel.status.to_s.humanize, css: "bg-slate-100 text-slate-500 border-slate-200" }
    content_tag :span, style[:label],
                class: "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border #{style[:css]}"
  end
end
