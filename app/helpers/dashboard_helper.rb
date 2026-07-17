module DashboardHelper
  HEALTH_BANDS = {
    "healthy"   => { label: "Saudável",  stroke: "#0d9488", text: "text-teal-700",  soft: "text-teal-600" },
    "attention" => { label: "Atenção",   stroke: "#d97706", text: "text-amber-700", soft: "text-amber-600" },
    "critical"  => { label: "Crítico",   stroke: "#dc2626", text: "text-red-700",   soft: "text-red-600" }
  }.freeze

  def health_band(band) = HEALTH_BANDS[band.to_s] || HEALTH_BANDS["attention"]

  INSIGHT_SEVERITY = {
    "critical" => { dot: "bg-red-500",   ring: "border-red-200 bg-red-50",     text: "text-red-700" },
    "warning"  => { dot: "bg-amber-500", ring: "border-amber-200 bg-amber-50", text: "text-amber-700" },
    "info"     => { dot: "bg-teal-500",  ring: "border-teal-200 bg-teal-50",   text: "text-teal-700" }
  }.freeze

  def insight_severity(severity) = INSIGHT_SEVERITY[severity.to_s] || INSIGHT_SEVERITY["info"]

  ESSENTIALITY_COLORS = {
    "essential"             => "bg-teal-500",
    "operational_important" => "bg-sky-500",
    "non_essential"         => "bg-amber-500",
    "superfluous"           => "bg-red-500",
    "review"                => "bg-slate-300"
  }.freeze

  def essentiality_color(key) = ESSENTIALITY_COLORS[key.to_s] || "bg-slate-300"

  # Paleta cíclica para categorias/rankings.
  CHART_PALETTE = %w[#0d9488 #6366f1 #f59e0b #ec4899 #14b8a6 #8b5cf6 #ef4444 #64748b].freeze
  def chart_color(index) = CHART_PALETTE[index % CHART_PALETTE.size]

  # Largura percentual de uma barra (0..100) protegida contra divisão por zero.
  def bar_width(value, max)
    return "0%" if max.to_f.zero?
    "#{[(value.to_f / max * 100).round(1), 100].min}%"
  end

  MESES = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze

  # "2026-07" -> "jul". Rótulo curto de mês para os gráficos.
  def month_short(label)
    _y, m = label.to_s.split("-").map(&:to_i)
    (m && m.between?(1, 12)) ? MESES[m - 1] : label
  end

  # "R$ 1,2 mil" / "R$ 3,4 mi" — versão compacta para eixos/legendas.
  def brl_compact(cents)
    v = cents.to_i / 100.0
    if v.abs >= 1_000_000 then "R$ #{number_with_precision(v / 1_000_000, precision: 1, separator: ',')} mi"
    elsif v.abs >= 1_000  then "R$ #{number_with_precision(v / 1_000, precision: 1, separator: ',')} mil"
    else format_brl(cents)
    end
  end

  def burn_trend_label(trend)
    { "up" => "em alta", "down" => "em queda", "stable" => "estável" }[trend.to_s] || "estável"
  end
end
