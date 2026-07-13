require "test_helper"

class Aionis::Integrations::RegistryTest < ActiveSupport::TestCase
  Registry = Aionis::Integrations::Registry
  Errors   = Aionis::Integrations::Errors

  test "resolve retorna NullProvider por padrão para todos os tipos" do
    registry = Registry.new({})

    assert_instance_of Aionis::Integrations::Whatsapp::NullProvider,     registry.resolve(:whatsapp)
    assert_instance_of Aionis::Integrations::OpenFinance::NullProvider,  registry.resolve(:open_finance)
    assert_instance_of Aionis::Integrations::Ocr::NullProvider,          registry.resolve(:ocr)
    assert_instance_of Aionis::Integrations::Ai::NullProvider,           registry.resolve(:ai)
  end

  test "resolve memoiza a instância" do
    registry = Registry.new({})
    assert_same registry.resolve(:ocr), registry.resolve(:ocr)
  end

  test "configured? é false para NullProvider" do
    assert_not Registry.new({}).configured?(:ai)
  end

  test "tipo desconhecido levanta UnknownIntegrationType" do
    assert_raises(Errors::UnknownIntegrationType) { Registry.new({}).resolve(:sms) }
  end

  test "provider inexistente na config levanta UnknownProvider" do
    registry = Registry.new("ocr" => { "provider" => "tesseract" })
    assert_raises(Errors::UnknownProvider) { registry.resolve(:ocr) }
  end

  test "config pode registrar e ativar um provedor customizado" do
    registry = Registry.new(
      "ocr" => {
        "provider"  => "custom",
        "providers" => { "custom" => "Aionis::Integrations::Ocr::NullProvider" },
        "settings"  => { "endpoint" => "http://exemplo" }
      }
    )
    provider = registry.resolve(:ocr)
    assert_instance_of Aionis::Integrations::Ocr::NullProvider, provider
    assert_equal "http://exemplo", provider.settings[:endpoint]
    assert_equal "custom", registry.active_provider_key(:ocr)
  end

  test "override tem precedência e reset! restaura" do
    registry = Registry.new({})
    fake = Object.new
    registry.override(:ocr, fake)
    assert_same fake, registry.resolve(:ocr)

    registry.reset!
    assert_instance_of Aionis::Integrations::Ocr::NullProvider, registry.resolve(:ocr)
  end

  test "clear_override volta a construir da config" do
    registry = Registry.new({})
    registry.override(:ai, Object.new)
    registry.clear_override(:ai)
    assert_instance_of Aionis::Integrations::Ai::NullProvider, registry.resolve(:ai)
  end

  test "from_config carrega o arquivo real e resolve nulls no ambiente de teste" do
    registry = Registry.from_config
    Aionis::Integrations::TYPES.each do |type|
      assert_equal "null", registry.active_provider_key(type)
      assert_not registry.configured?(type)
    end
  end

  test "classe de provedor inválida levanta ProviderNotLoadable" do
    registry = Registry.new(
      "ocr" => { "provider" => "x", "providers" => { "x" => "Nao::Existe::Classe" } }
    )
    assert_raises(Errors::ProviderNotLoadable) { registry.resolve(:ocr) }
  end
end
