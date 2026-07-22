require "test_helper"

# Canal WhatsApp do Agente: texto entra no MESMO orquestrador do portal e a
# resposta sai pelo caminho padrão (Responder -> OutgoingMessage -> SendMessageJob).
class Aionis::Agent::WhatsappReplyJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class FakeAi
    def configured? = true
    def chat(messages:, system: nil, tools: [], model: nil, max_tokens: nil)
      Aionis::Integrations::Result.ok(provider: "anthropic", data: {
        "content" => [{ "type" => "text", "text" => "Seu saldo é R$ 700,00" }],
        "stop_reason" => "end_turn"
      })
    end
  end

  class BrokenAi
    def configured? = true
    def chat(**) = raise "boom"
  end

  setup do
    @user = User.create!(name: "W", email: "wjob_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user, whatsapp_number: "5511888")
    @channel = @workspace.workspace_channels.create!(provider: "meta_cloud", status: "connected")
    @incoming = @channel.incoming_messages.create!(
      workspace: @workspace, wa_message_id: "TXT1", kind: "text",
      from_number: "5511888", text: "qual meu saldo?", status: "received"
    )
  end

  teardown { Aionis::Integrations.reset! }

  test "roda o orquestrador e responde via OutgoingMessage" do
    Aionis::Integrations.override(:ai, FakeAi.new)

    assert_difference -> { OutgoingMessage.count }, 1 do
      Aionis::Agent::WhatsappReplyJob.new.perform(@incoming.id)
    end

    out = OutgoingMessage.last
    assert_equal "Seu saldo é R$ 700,00", out.body
    assert_equal "5511888", out.to_number
    assert_equal "processed", @incoming.reload.status
    # Mesmo orquestrador: mensagens persistidas no canal whatsapp
    assert_equal %w[user assistant], @workspace.agent_messages.for_channel("whatsapp").chronological.pluck(:role)
  end

  test "falha do agente degrada para a resposta de ajuda (nunca silencia)" do
    Aionis::Integrations.override(:ai, BrokenAi.new)

    assert_difference -> { OutgoingMessage.count }, 1 do
      Aionis::Agent::WhatsappReplyJob.new.perform(@incoming.id)
    end
    assert_equal "processed", @incoming.reload.status
  end

  # --- Roteamento no InboundProcessor ---------------------------------------

  class FakeWhatsapp
    def initialize(inbound) = @inbound = inbound
    def configured? = true
    def parse_inbound(_payload) = Aionis::Integrations::Result.ok(provider: "meta_cloud", data: @inbound)
    def send_text(to:, body:, instance: nil, credentials: nil)
      Aionis::Integrations::Result.ok(provider: "meta_cloud", data: { "message_id" => "OUT1" })
    end
  end

  def text_inbound(id: "T#{SecureRandom.hex(3)}")
    { "event" => "message", "type" => "text", "wa_message_id" => id,
      "from" => "5511888", "phone_number_id" => "PN", "text" => "oi, quanto gastei?" }
  end

  test "texto é roteado ao agente quando a IA está configurada" do
    Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new(text_inbound))
    Aionis::Integrations.override(:ai, FakeAi.new)

    assert_enqueued_with(job: Aionis::Agent::WhatsappReplyJob) do
      Aionis::Whatsapp::InboundProcessor.call(provider: "meta_cloud", payload: {})
    end
  end

  test "sem IA configurada, texto mantém a resposta de ajuda de sempre" do
    Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new(text_inbound))
    # IA fica no NullProvider (default em test) → agente desabilitado

    assert_no_enqueued_jobs(only: Aionis::Agent::WhatsappReplyJob) do
      assert_difference -> { OutgoingMessage.count }, 1 do
        Aionis::Whatsapp::InboundProcessor.call(provider: "meta_cloud", payload: {})
      end
    end
    assert_match(/comprovante/i, OutgoingMessage.last.body)
  end

  test "mídia continua no pipeline de OCR, nunca no agente" do
    media = { "event" => "message", "type" => "image", "wa_message_id" => "IMG1",
              "from" => "5511888", "phone_number_id" => "PN",
              "media" => { "id" => "m1", "mimetype" => "image/png" } }
    Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new(media))
    Aionis::Integrations.override(:ai, FakeAi.new)

    assert_enqueued_with(job: Aionis::Whatsapp::DownloadMediaJob) do
      assert_no_enqueued_jobs(only: Aionis::Agent::WhatsappReplyJob) do
        Aionis::Whatsapp::InboundProcessor.call(provider: "meta_cloud", payload: {})
      end
    end
  end
end
