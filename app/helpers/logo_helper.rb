# frozen_string_literal: true

# Marca do Aionis. Os SVGs vivem em app/assets/images/logo/ e são INLINE na
# página (não <img>) para que herdem cor via `currentColor` e sejam
# dimensionados por classe Tailwind — impossível com <img>.
#
#   <%= aionis_logo :icon_dark, class: "w-5 h-5" %>          marca só
#   <%= aionis_logo :full, class: "h-8 w-auto" %>            lockup horizontal
#   <%= aionis_logo :stacked, class: "h-24 w-auto" %>        lockup empilhado
#
# Qual usar onde:
#   :full          fundo claro  — landing, páginas públicas
#   :full_dark     fundo escuro — seções ink, e-mails invertidos
#   :full_solid    uma cor só   — impressão, fax, baixa fidelidade
#   :stacked       centralizado — login, cadastro, splash
#   :icon          marca em fundo claro
#   :icon_dark     marca em fundo escuro (sidebar navy)
#   :icon_mono     herda currentColor (segue a cor do texto ao redor)
#   :icon_badge    quadrado com gradiente — avatar, app icon, favicon grande
module LogoHelper
  VARIANTS = {
    full:       "aionis-finance-logo.svg",
    full_dark:  "aionis-finance-logo-dark.svg",
    full_solid: "aionis-finance-logo-solid.svg",
    stacked:    "aionis-finance-logo-stacked.svg",
    icon:       "aionis-icon.svg",
    icon_dark:  "aionis-icon-dark.svg",
    icon_mono:  "aionis-icon-mono.svg",
    icon_badge: "aionis-icon-badge.svg"
  }.freeze

  DEFAULT_LABEL = "Aionis Finance"

  def aionis_logo(variant = :full, css_class: nil, label: DEFAULT_LABEL, **)
    # LogoHelper. explícito: dentro de uma view, `self.class` é a classe da
    # view (que não tem o método de módulo), não este módulo.
    source = LogoHelper.aionis_logo_source(variant)
    return "".html_safe if source.blank?

    # width/height fixos do arquivo atrapalham o dimensionamento por CSS; a
    # viewBox (preservada) é o que mantém a proporção correta.
    svg = source
          .sub(/\s+width="[^"]*"/, "")
          .sub(/\s+height="[^"]*"/, "")
          .sub(/\s+aria-label="[^"]*"/, %( aria-label="#{ERB::Util.html_escape(label)}"))
    svg = svg.sub("<svg", %(<svg class="#{ERB::Util.html_escape(css_class)}")) if css_class.present?
    svg.html_safe
  end

  # Lê e memoiza o arquivo. Em desenvolvimento relê a cada chamada para que
  # editar o SVG apareça sem reiniciar o servidor.
  def self.aionis_logo_source(variant)
    file = VARIANTS[variant.to_sym]
    raise ArgumentError, "Variante de logo desconhecida: #{variant.inspect}. Use: #{VARIANTS.keys.join(', ')}" if file.nil?

    return read_logo(file) unless Rails.env.production?

    @cache ||= {}
    @cache[file] ||= read_logo(file)
  end

  def self.read_logo(file)
    path = Rails.root.join("app", "assets", "images", "logo", file)
    File.exist?(path) ? File.read(path) : ""
  end
end
