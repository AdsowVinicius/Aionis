require "test_helper"

class Webhooks::WhatsappControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Fake que cobre validação do Evolution (token) e da Meta (challenge + HMAC).
  class FakeWhatsapp
    def verify_webhook(token: nil, mode: nil, challenge: nil)
      if mode == "subscribe" && token == "vt"
        Aionis::Integrations::Result.ok(provider: "meta_cloud", data: { "challenge" => challenge })
      elsif token == "sec"
        Aionis::Integrations::Result.ok(provider: "evolution", data: {})
      else
        Aionis::Integrations::Result.error(provider: "whatsapp", message: "inválido")
      end
    end

    def verify_signature(raw_body:, signature:)
      if signature == "sha256=valid"
        Aionis::Integrations::Result.ok(provider: "meta_cloud", data: {})
      else
        Aionis::Integrations::Result.error(provider: "meta_cloud", message: "assinatura inválida")
      end
    end
  end

  setup { Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new) }
  teardown { Aionis::Integrations.reset! }

  PAYLOAD = { "entry" => [{ "changes" => [{ "value" => { "messages" => [{ "id" => "M1" }] } }] }] }.freeze

  # --- Evolution ---

  test "Evolution: token válido responde 200 e enfileira" do
    assert_enqueued_with(job: Aionis::Whatsapp::InboundJob) do
      post whatsapp_webhook_path("aionis"),
           params: PAYLOAD.to_json, headers: { "apikey" => "sec", "Content-Type" => "application/json" }
    end
    assert_response :ok
  end

  test "Evolution: token inválido responde 401 sem enfileirar" do
    assert_no_enqueued_jobs do
      post whatsapp_webhook_path("aionis"),
           params: PAYLOAD.to_json, headers: { "apikey" => "errado", "Content-Type" => "application/json" }
    end
    assert_response :unauthorized
  end

  # --- Meta Cloud ---

  test "Meta: verificação GET ecoa o challenge com token correto" do
    get whatsapp_meta_verify_path,
        params: { "hub.mode" => "subscribe", "hub.verify_token" => "vt", "hub.challenge" => "12345" }
    assert_response :ok
    assert_equal "12345", response.body
  end

  test "Meta: verificação GET com token errado responde 403" do
    get whatsapp_meta_verify_path,
        params: { "hub.mode" => "subscribe", "hub.verify_token" => "errado", "hub.challenge" => "x" }
    assert_response :forbidden
  end

  test "Meta: POST com assinatura válida responde 200 e enfileira" do
    assert_enqueued_with(job: Aionis::Whatsapp::InboundJob) do
      post whatsapp_meta_webhook_path,
           params: PAYLOAD.to_json,
           headers: { "X-Hub-Signature-256" => "sha256=valid", "Content-Type" => "application/json" }
    end
    assert_response :ok
  end

  test "Meta: POST com assinatura inválida responde 401 sem enfileirar" do
    assert_no_enqueued_jobs do
      post whatsapp_meta_webhook_path,
           params: PAYLOAD.to_json,
           headers: { "X-Hub-Signature-256" => "sha256=errado", "Content-Type" => "application/json" }
    end
    assert_response :unauthorized
  end
end
