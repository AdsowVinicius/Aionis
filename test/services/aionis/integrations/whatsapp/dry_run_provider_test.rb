require "test_helper"

class Aionis::Integrations::Whatsapp::DryRunProviderTest < ActiveSupport::TestCase
  setup { @provider = Aionis::Integrations::Whatsapp::DryRunProvider.new }

  test "send_text não chama rede, loga [WHATSAPP_DRY_RUN] e devolve Result de sucesso" do
    log = capture_log { @result = @provider.send_text(to: "5511999", body: "Lançamento registrado") }

    assert @result.success?, "Result deveria ser sucesso"
    assert_equal "dry_run", @result.provider
    assert @result.data["dry_run"]
    assert_match(/\Adryrun-/, @result.data["message_id"])
    assert_match(/\[WHATSAPP_DRY_RUN\]/, log)
    assert_match(/5511999/, log)
  end

  test "provider_key é dry_run e configured? é true" do
    assert_equal "dry_run", @provider.provider_key
    assert @provider.configured?
  end

  test "os demais métodos de envio também devolvem sucesso sem rede" do
    assert @provider.send_document(to: "5511999", media: "http://x/a.pdf", caption: "nota").success?
    assert @provider.send_image(to: "5511999", media: "http://x/a.png").success?
    assert @provider.mark_as_read(message_id: "WAMID1").success?
  end

  test "é resolvido pela Integration Layer com a chave dry_run" do
    provider = Aionis::Integrations.whatsapp(provider: "dry_run")
    assert_instance_of Aionis::Integrations::Whatsapp::DryRunProvider, provider
  ensure
    Aionis::Integrations.reset!
  end

  private

  def capture_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end
end
