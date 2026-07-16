require "test_helper"

class Webhooks::WhatsappControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  # Provider fake só para validar o token no controller.
  class FakeWhatsapp
    def verify_webhook(token:, mode: nil, challenge: nil)
      if token == "sec"
        Aionis::Integrations::Result.ok(provider: "evolution", data: {})
      else
        Aionis::Integrations::Result.error(provider: "evolution", message: "token inválido")
      end
    end
  end

  setup { Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new) }
  teardown { Aionis::Integrations.reset! }

  PAYLOAD = { "event" => "messages.upsert", "instance" => "aionis",
              "data" => { "key" => { "id" => "M1" } } }.freeze

  test "token válido responde 200 e enfileira o processamento" do
    assert_enqueued_with(job: Aionis::Whatsapp::InboundJob) do
      post whatsapp_webhook_path("aionis"),
           params: PAYLOAD.to_json,
           headers: { "apikey" => "sec", "Content-Type" => "application/json" }
    end
    assert_response :ok
  end

  test "token inválido responde 401 sem enfileirar" do
    assert_no_enqueued_jobs do
      post whatsapp_webhook_path("aionis"),
           params: PAYLOAD.to_json,
           headers: { "apikey" => "errado", "Content-Type" => "application/json" }
    end
    assert_response :unauthorized
  end

  test "aceita token via query param" do
    post whatsapp_webhook_path("aionis", token: "sec"),
         params: PAYLOAD.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :ok
  end
end
