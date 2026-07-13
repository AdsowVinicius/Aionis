require "test_helper"

# Testa a facade Aionis::Integrations (ponto único de acesso + injeção de
# dependência). Usa um registry isolado para não vazar estado entre testes.
class Aionis::IntegrationsTest < ActiveSupport::TestCase
  setup do
    @original = Aionis::Integrations.registry
    Aionis::Integrations.registry = Aionis::Integrations::Registry.new({})
  end

  teardown do
    Aionis::Integrations.registry = @original
  end

  test "atalhos retornam o provedor null por padrão" do
    assert_instance_of Aionis::Integrations::Whatsapp::NullProvider,    Aionis::Integrations.whatsapp
    assert_instance_of Aionis::Integrations::OpenFinance::NullProvider, Aionis::Integrations.open_finance
    assert_instance_of Aionis::Integrations::Ocr::NullProvider,         Aionis::Integrations.ocr
    assert_instance_of Aionis::Integrations::Ai::NullProvider,          Aionis::Integrations.ai
  end

  test "override troca o provedor sem o consumidor saber" do
    fake = Aionis::Integrations::Ai::NullProvider.new
    Aionis::Integrations.override(:ai, fake)
    assert_same fake, Aionis::Integrations.ai
  end

  test "with aplica override apenas dentro do bloco" do
    fake = Object.new
    Aionis::Integrations.with(ocr: fake) do
      assert_same fake, Aionis::Integrations.ocr
    end
    assert_instance_of Aionis::Integrations::Ocr::NullProvider, Aionis::Integrations.ocr
  end

  test "with restaura mesmo se o bloco levantar" do
    fake = Object.new
    assert_raises(RuntimeError) do
      Aionis::Integrations.with(ocr: fake) { raise "boom" }
    end
    assert_instance_of Aionis::Integrations::Ocr::NullProvider, Aionis::Integrations.ocr
  end

  test "configured? delega ao registry" do
    assert_not Aionis::Integrations.configured?(:whatsapp)
  end
end
