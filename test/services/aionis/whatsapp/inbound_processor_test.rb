require "test_helper"

class Aionis::Whatsapp::InboundProcessorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Provider WhatsApp fake: devolve o inbound normalizado e a mídia.
  class FakeWhatsapp
    def initialize(inbound:) = @inbound = inbound
    def parse_inbound(_payload)
      Aionis::Integrations::Result.ok(provider: "evolution", data: @inbound)
    end
    def download_media(_media, instance: nil)
      Aionis::Integrations::Result.ok(provider: "evolution",
        data: { "bytes" => "fake-bytes", "mimetype" => "image/png", "filename" => "recibo.png" })
    end
    def send_text(to:, body:, instance: nil)
      Aionis::Integrations::Result.ok(provider: "evolution", data: { "message_id" => "OUT1" })
    end
  end

  # OCR fake: texto rico o suficiente para confiança alta.
  class FakeOcr
    def initialize(text:, confidence: 95) = (@text = text; @confidence = confidence)
    def extract(io:, content_type:, filename: nil)
      Aionis::Integrations::Result.ok(provider: "tesseract",
        data: { "text" => @text, "confidence" => @confidence, "pages" => 1, "words" => 5 })
    end
  end

  setup do
    @user = User.create!(name: "WA", email: "wain_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @channel = @workspace.workspace_channels.create!(instance: "aionis", provider: "evolution")
  end

  teardown { Aionis::Integrations.reset! }

  def media_inbound(id: "M1")
    {
      "type" => "image", "wa_message_id" => id, "from" => "5511999", "instance" => "aionis",
      "from_me" => false, "push_name" => "João", "text" => nil,
      "media" => { "mimetype" => "image/png", "filename" => "r.png", "key" => {} },
      "received_at" => Time.current.utc.iso8601
    }
  end

  def process(inbound, ocr_text: "MERCADO X\nCNPJ 11.222.333/0001-81\nData 10/07/2026\nTOTAL R$ 50,00", ocr_conf: 95)
    Aionis::Integrations.override(:whatsapp, FakeWhatsapp.new(inbound: inbound))
    Aionis::Integrations.override(:ocr, FakeOcr.new(text: ocr_text, confidence: ocr_conf))
    Aionis::Whatsapp::InboundProcessor.call(instance: "aionis", payload: {})
  end

  test "mídia com alta confiança cria documento e lançamento confirmado" do
    assert_difference -> { Document.count } => 1,
                      -> { FinancialTransaction.count } => 1,
                      -> { IncomingMessage.count } => 1,
                      -> { OutgoingMessage.count } => 1 do
      process(media_inbound)
    end

    doc = Document.last
    assert_equal "whatsapp", doc.source

    tx = FinancialTransaction.last
    assert_equal "document", tx.origin
    assert_equal 5_000, tx.amount_cents
    assert_equal "confirmed", tx.status

    incoming = IncomingMessage.last
    assert_equal "processed", incoming.status
    assert_equal doc.id, incoming.document_id

    assert_match "registrado", OutgoingMessage.last.body
  end

  test "confiança média cria lançamento pendente e pede confirmação" do
    # Com valor+data+nome, mas sem CNPJ válido → faixa 61-85
    tx_before = FinancialTransaction.count
    process(media_inbound, ocr_text: "PADARIA CENTRAL\nData 10/07/2026\nTOTAL R$ 20,00", ocr_conf: 90)

    tx = FinancialTransaction.last
    assert_equal "pending", tx.status
    assert_equal tx_before + 1, FinancialTransaction.count
    assert_match "pendente", OutgoingMessage.last.body
  end

  test "baixa confiança não cria lançamento e pede reenvio" do
    assert_no_difference -> { FinancialTransaction.count } do
      process(media_inbound, ocr_text: "borrado ilegível", ocr_conf: 20)
    end
    assert_match(/nítida/i, OutgoingMessage.last.body)
  end

  test "mensagem de texto responde com ajuda" do
    text_inbound = { "type" => "text", "wa_message_id" => "T1", "from" => "5511999",
                     "instance" => "aionis", "from_me" => false, "text" => "oi" }
    assert_no_difference -> { Document.count } do
      process(text_inbound)
    end
    assert_match(/comprovante/i, OutgoingMessage.last.body)
  end

  test "deduplica mensagens repetidas (mesmo wa_message_id)" do
    process(media_inbound(id: "DUP"))
    assert_no_difference -> { IncomingMessage.count } do
      process(media_inbound(id: "DUP"))
    end
  end

  test "mensagem própria (from_me) é ignorada" do
    own = media_inbound(id: "OWN").merge("from_me" => true)
    assert_no_difference -> { IncomingMessage.count } do
      process(own)
    end
  end

  test "registra AuditLog de integração" do
    process(media_inbound(id: "AUD"))
    assert AuditLog.where(action: "integration", origin: "integration").exists?
  end
end
