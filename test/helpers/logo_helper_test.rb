require "test_helper"

class LogoHelperTest < ActionView::TestCase
  include LogoHelper

  test "todas as variantes existem em app/assets/images/logo" do
    LogoHelper::VARIANTS.each do |variant, file|
      path = Rails.root.join("app", "assets", "images", "logo", file)
      assert File.exist?(path), "arquivo da variante #{variant} não existe: #{file}"
      assert_match(/<svg/, aionis_logo(variant), "variante #{variant} não renderizou SVG")
    end
  end

  test "remove width/height fixos para o CSS poder dimensionar, mas preserva a viewBox" do
    svg = aionis_logo(:full, css_class: "h-8 w-auto")

    refute_match(/\swidth="/, svg)
    refute_match(/\sheight="/, svg)
    assert_match(/viewBox="0 0 340 72"/, svg)
    assert_match(/class="h-8 w-auto"/, svg)
  end

  test "aria-label acessível, com sobrescrita" do
    assert_match(/aria-label="Aionis Finance"/, aionis_logo(:icon))
    assert_match(/aria-label="Voltar ao início"/, aionis_logo(:icon, label: "Voltar ao início"))
  end

  test "escapa o que vem de fora (sem injeção de HTML no atributo)" do
    svg = aionis_logo(:icon, css_class: '"><script>alert(1)</script>')

    refute_includes svg, "<script>"
    assert_includes svg, "&lt;script&gt;"
  end

  test "variante desconhecida falha alto em vez de renderizar vazio" do
    error = assert_raises(ArgumentError) { aionis_logo(:inexistente) }
    assert_match(/Variante de logo desconhecida/, error.message)
  end

  test "a variante mono herda a cor do texto ao redor" do
    assert_match(/stroke="currentColor"/, aionis_logo(:icon_mono))
  end
end
