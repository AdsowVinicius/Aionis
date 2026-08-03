require "test_helper"

# Os ícones já foram para produção uma vez como o CÍRCULO VERMELHO padrão do
# Rails — favicon e imagem de preview ao compartilhar o site no WhatsApp.
# E como ficavam em /public (URL sem digest, cache de 1 ano), trocar o arquivo
# não bastava: o CDN seguia servindo o antigo. Estes testes travam as duas
# coisas: arte correta e URL versionada.
class IconsTest < ActionDispatch::IntegrationTest
  ICON_SVG = Rails.root.join("app/assets/images/icon.svg")
  ICON_PNG = Rails.root.join("app/assets/images/icon.png")

  ICON_DARK = Rails.root.join("app/assets/images/icon-dark.svg")

  test "o ícone não é o placeholder vermelho do Rails" do
    svg = File.read(ICON_SVG)
    refute_match(/fill="red"/i, svg, "icon.svg ainda é o placeholder do Rails")
    assert_match(/#14B88A/i, svg, "icon.svg deveria usar o teal da marca")
    assert_match(/#0E1B2C/i, svg, "icon.svg deveria usar o navy da marca")
  end

  # Decisão de marca: só o "A" com o check, sem container. Um <rect> de fundo
  # significa que alguém trouxe a versão em badge de volta.
  test "o ícone é o A sem fundo" do
    refute_match(/<rect/i, File.read(ICON_SVG), "icon.svg voltou a ter fundo")
    refute_match(/<rect/i, File.read(ICON_DARK), "icon-dark.svg voltou a ter fundo")
  end

  test "o PNG existe e tem tamanho de arte real" do
    assert File.exist?(ICON_PNG)
    assert_operator File.size(ICON_PNG), :>, 3_000,
                    "icon.png pequeno demais — provavelmente ainda é o placeholder"
  end

  test "favicons saem com digest (senão o CDN prende a arte antiga por 1 ano)" do
    get root_path
    hrefs = response.body.scan(/<link rel="(?:apple-touch-)?icon"[^>]*href="([^"]+)"/).flatten

    assert_equal 4, hrefs.size, "esperava svg + svg dark + png + apple-touch-icon"
    hrefs.each do |href|
      assert_match(%r{\A/assets/icon(-dark)?-[0-9a-f]+\.(svg|png)\z}, href,
                   "#{href} não tem digest — trocar a arte não invalidaria o cache")
    end
  end

  # O "A" é navy: numa aba em modo escuro ele sumiria no fundo.
  test "há variante clara do favicon para o dark mode" do
    get root_path
    assert_match(
      %r{<link rel="icon" href="/assets/icon-dark-[0-9a-f]+\.svg"[^>]*media="\(prefers-color-scheme: dark\)"},
      response.body
    )
  end

  test "og:image aponta para o ícone versionado, em URL absoluta" do
    get root_path
    og = response.body[/property="og:image" content="([^"]+)"/, 1]

    assert_match(%r{\Ahttps?://.+/assets/icon-[0-9a-f]+\.png\z}, og)
  end

  test "manifest do PWA responde e usa os ícones da marca" do
    get pwa_manifest_path
    assert_response :success

    manifest = JSON.parse(response.body)
    assert_equal "#0E1B2C", manifest["theme_color"]
    assert_equal "#F5F4EF", manifest["background_color"]
    refute_equal "red", manifest["theme_color"]
    manifest["icons"].each { |i| assert_match(%r{/assets/icon-[0-9a-f]+\.}, i["src"]) }
  end
end
