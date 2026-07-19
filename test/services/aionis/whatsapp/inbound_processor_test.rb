require "test_helper"

class Aionis::Whatsapp::InboundProcessorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Provider WhatsApp fake (serve Meta e Evolution — o processor é agnóstico).
  class FakeWhatsapp
    def initialize(inbound:, bytes: "fake-bytes")
      @inbound = inbound
      @bytes = bytes
    end
    def configured? = true
    def parse_inbound(_payload)
      Aionis::Integrations::Result.ok(provider: "meta_cloud", data: @inbound)
    end
    def download_media(_media, instance: nil, credentials: nil)
      Aionis::Integrations::Result.ok(provider: "meta_cloud",
        data: { "bytes" => @bytes, "mimetype" => "image/png", "filename" => "recibo.png", "url" => "http://x" })
    end
    def send_text(to:, body:, instance: nil, credentials: nil)
      Aionis::Integrations::Result.ok(provider: "meta_cloud", data: { "message_id" => "OUT1" })
    end
    def mark_as_read(message_id:, instance: nil, credentials: nil)
      Aionis::Integrations::Result.ok(provider: "meta_cloud", data: {})
    end
  end

  class FakeOcr
    def initialize(text:, confidence: 95) = (@text = text; @confidence = confidence)
    def extract(io:, content_type:, filename: nil)
      Aionis::Integrations::Result.ok(provider: "tesseract",
        data: { "text" => @text, "confidence" => @confidence, "pages" => 1, "words" => 5 })
    end
  end

  setup do
    @user = User.create!(name: "WA", email: "wain_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    # O remetente é reconhecido pelo número dele (número do Aionis é global).
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user, whatsapp_number: "5511999")
    @channel = @workspace.workspace_channels.create!(provider: "meta_cloud", status: "connected")
  end

  teardown { Aionis::Integrations.reset! }

  def media_inbound(id: "M1", type: "image")
    {
      "event" => "message", "type" => type, "wa_message_id" => id, "from" => "5511999",
      "phone_number_id" => "PN123", "from_me" => false, "push_name" => "João", "text" => nil,
      "media" => { "id" => "m1", "mimetype" => "image/png", "filename" => "r.png" },
      "received_at" => Time.current.utc.iso8601
    }
  end

  def run_inbound(inbound, ocr_text: "MERCADO X\nCNPJ 11.222.333/0001-81\nData 10/07/2026\nTOTAL R$ 50,00", ocr_conf: 95)
    Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new(inbound: inbound))
    Aionis::Integrations.override(:ocr, FakeOcr.new(text: ocr_text, confidence: ocr_conf))
    perform_enqueued_jobs do
      Aionis::Whatsapp::InboundProcessor.call(provider: "meta_cloud", payload: {})
    end
  end

  test "pipeline assíncrono cria mensagem, documento e lançamento confirmado" do
    assert_difference -> { IncomingMessage.count } => 1,
                      -> { Document.count } => 1,
                      -> { FinancialTransaction.count } => 1,
                      -> { OutgoingMessage.count } => 1 do
      run_inbound(media_inbound)
    end

    doc = Document.last
    assert_equal "whatsapp", doc.source

    incoming = IncomingMessage.last
    assert_equal doc.id, incoming.document_id
    assert_equal "processed", incoming.status
    assert_equal "image/png", incoming.mime_type

    tx = FinancialTransaction.last
    assert_equal 5_000, tx.amount_cents
    assert_equal "confirmed", tx.status
    assert_match "registrado", OutgoingMessage.last.body
  end

  test "webhook só persiste e enfileira — não baixa nada de forma síncrona" do
    Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new(inbound: media_inbound))
    assert_no_difference -> { Document.count } do
      assert_enqueued_with(job: Aionis::Whatsapp::DownloadMediaJob) do
        Aionis::Whatsapp::InboundProcessor.call(provider: "meta_cloud", payload: {})
      end
    end
    assert_equal 1, IncomingMessage.count
  end

  test "confiança média cria lançamento pendente" do
    run_inbound(media_inbound, ocr_text: "PADARIA CENTRAL\nData 10/07/2026\nTOTAL R$ 20,00", ocr_conf: 90)
    tx = FinancialTransaction.last
    assert_equal "pending", tx.status
    assert_match "pendente", OutgoingMessage.last.body
  end

  test "baixa confiança não cria lançamento" do
    assert_no_difference -> { FinancialTransaction.count } do
      run_inbound(media_inbound, ocr_text: "ilegível", ocr_conf: 10)
    end
    assert_match(/nítida/i, OutgoingMessage.last.body)
  end

  test "texto responde com ajuda" do
    text_inbound = { "event" => "message", "type" => "text", "wa_message_id" => "T1",
                     "from" => "5511999", "phone_number_id" => "PN123", "text" => "oi" }
    assert_no_difference -> { Document.count } do
      run_inbound(text_inbound)
    end
    assert_match(/comprovante/i, OutgoingMessage.last.body)
  end

  test "áudio é registrado mas não processado" do
    audio = media_inbound(id: "A1", type: "audio")
    assert_no_difference -> { Document.count } do
      run_inbound(audio)
    end
    assert_equal "audio", IncomingMessage.last.kind
    assert_match(/áudio/i, OutgoingMessage.last.body)
  end

  test "idempotência: mesma mensagem não duplica" do
    run_inbound(media_inbound(id: "DUP"))
    assert_no_difference -> { IncomingMessage.count } do
      run_inbound(media_inbound(id: "DUP"))
    end
  end

  test "mensagem própria (from_me) é ignorada" do
    own = media_inbound(id: "OWN").merge("from_me" => true)
    assert_no_difference -> { IncomingMessage.count } do
      run_inbound(own)
    end
  end

  test "callback de status atualiza a OutgoingMessage" do
    incoming = @channel.incoming_messages.create!(workspace: @workspace, wa_message_id: "IN1", kind: "text")
    out = @channel.outgoing_messages.create!(workspace: @workspace, incoming_message: incoming,
                                             to_number: "5511999", body: "x", provider_message_id: "WAMID1")
    out.mark_sent!("WAMID1")

    status = { "event" => "status", "wa_message_id" => "WAMID1", "status" => "delivered", "phone_number_id" => "PN123" }
    Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new(inbound: status))
    Aionis::Whatsapp::InboundProcessor.call(provider: "meta_cloud", payload: {})

    assert_equal "delivered", out.reload.status
  end

  test "registra AuditLog de integração" do
    run_inbound(media_inbound(id: "AUD"))
    assert AuditLog.where(action: "integration", origin: "integration").exists?
  end

  test "remetente não cadastrado em nenhum workspace é ignorado" do
    desconhecido = media_inbound(id: "UNK").merge("from" => "5599000000000")
    assert_no_difference -> { IncomingMessage.count } do
      run_inbound(desconhecido)
    end
  end
end
