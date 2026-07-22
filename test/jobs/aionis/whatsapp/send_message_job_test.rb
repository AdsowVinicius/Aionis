require "test_helper"

class Aionis::Whatsapp::SendMessageJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class OkProvider
    def send_text(to:, body:, instance: nil, credentials: nil)
      Aionis::Integrations::Result.ok(provider: "evolution", data: { "message_id" => "OUT9" })
    end
  end

  class FailProvider
    def send_text(to:, body:, instance: nil, credentials: nil)
      Aionis::Integrations::Result.error(provider: "evolution", message: "offline")
    end
  end

  setup do
    @user = User.create!(name: "S", email: "send_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @channel = @workspace.workspace_channels.create!(instance: "aionis", provider: "evolution")
    @out = @channel.outgoing_messages.create!(workspace: @workspace, to_number: "5511999", body: "oi")
  end

  teardown { Aionis::Integrations.reset! }

  test "envio bem-sucedido marca sent com provider_message_id" do
    Aionis::Integrations.override(:whatsapp, OkProvider.new)
    Aionis::Whatsapp::SendMessageJob.new.perform(@out.id)

    @out.reload
    assert @out.sent?
    assert_equal "OUT9", @out.provider_message_id
    assert_equal 1, @out.attempts
  end

  test "mensagem já enviada não é reenviada" do
    @out.mark_sent!("PREV")
    Aionis::Integrations.override(:whatsapp, OkProvider.new)
    Aionis::Whatsapp::SendMessageJob.new.perform(@out.id)
    assert_equal 0, @out.reload.attempts
  end

  test "falha de envio levanta DeliveryError e conta tentativa" do
    Aionis::Integrations.override(:whatsapp, FailProvider.new)
    job = Aionis::Whatsapp::SendMessageJob.new

    assert_raises(Aionis::Whatsapp::DeliveryError) { job.perform(@out.id) }
    @out.reload
    assert @out.pending?
    assert_equal 1, @out.attempts
  end

  test "após esgotar as tentativas, marca como failed" do
    Aionis::Integrations.override(:whatsapp, FailProvider.new)

    perform_enqueued_jobs do
      Aionis::Whatsapp::SendMessageJob.perform_later(@out.id)
    end

    @out.reload
    assert @out.failed?, "deveria falhar após esgotar os retries"
    assert_operator @out.attempts, :>=, 3
  end

  test "dry-run ativo: não chama a Meta, marca dry_run e loga o envio suprimido" do
    # Sem override: o job resolve o DryRunProvider real via Registry.
    log = with_env("WHATSAPP_DRY_RUN", "true") do
      capture_log { assert_nothing_raised { Aionis::Whatsapp::SendMessageJob.new.perform(@out.id) } }
    end

    @out.reload
    assert @out.dry_run?, "status deveria ser dry_run"
    assert_equal 1, @out.attempts
    assert_match(/\Adryrun-/, @out.provider_message_id)
    assert_match(/\[WHATSAPP_DRY_RUN\]/, log)
  end

  test "dry-run inativo: usa o provider real com HTTP mockado e marca sent" do
    called = false
    fake_http = lambda do |_method, _url, _headers, _body|
      called = true
      Struct.new(:code, :body).new(200, { "messages" => [{ "id" => "WAMID_REAL" }] }.to_json)
    end
    meta = Aionis::Integrations::Whatsapp::MetaCloudProvider.new(
      phone_number_id: "PN", access_token: "TOK", graph_version: "v21.0", http: fake_http
    )

    with_env("WHATSAPP_DRY_RUN", "false") do
      Aionis::Integrations.override(:whatsapp, meta)
      Aionis::Whatsapp::SendMessageJob.new.perform(@out.id)
    end

    assert called, "o provider real deveria ter feito a chamada HTTP"
    @out.reload
    assert @out.sent?, "status deveria ser sent"
    assert_equal "WAMID_REAL", @out.provider_message_id
  end

  private

  def with_env(key, value)
    original = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = original
  end

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
