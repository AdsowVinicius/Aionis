require "test_helper"

class Aionis::DocumentExtractionServiceTest < ActiveSupport::TestCase
  PNG_PATH = Rails.root.join("test/fixtures/files/sample.png")
  XML_PATH = Rails.root.join("test/fixtures/files/sample_nfe.xml")

  # Provedor de OCR fake injetado via Integration Layer.
  class FakeOcr
    def initialize(result) = @result = result
    def extract(io:, content_type:, filename: nil) = @result
  end

  setup do
    @user = User.create!(name: "Extrai", email: "extrai_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS Extrai", kind: "empresa", owner: @user)
  end

  teardown { Aionis::Integrations.reset! }

  def image_document
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.file.attach(io: File.open(PNG_PATH), filename: "recibo.png", content_type: "image/png")
    doc.save!
    doc
  end

  def xml_document
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.file.attach(io: File.open(XML_PATH), filename: "nfe.xml", content_type: "text/xml")
    doc.save!
    doc
  end

  def stub_ocr(text:, confidence: 90)
    result = Aionis::Integrations::Result.ok(
      provider: "tesseract",
      data: { "text" => text, "confidence" => confidence, "pages" => 1, "words" => text.split.size }
    )
    Aionis::Integrations.override(:ocr, FakeOcr.new(result))
  end

  test "OCR bem-sucedido preenche raw_text, confiança e sugestão" do
    stub_ocr(text: "PADARIA CENTRAL\nData: 10/07/2026\nTOTAL R$ 25,00", confidence: 92)
    doc = image_document

    ext = Aionis::DocumentExtractionService.call(doc)

    assert_equal "tesseract", ext.processor_name
    assert_match "PADARIA", ext.raw_text
    assert_equal 2_500, ext.suggested_transaction_data["amount_cents"]
    assert_operator ext.confidence_score, :>, 0
    assert_equal "review", doc.reload.status
    assert_equal @workspace.id, ext.workspace_id
  end

  test "OCR registra AuditLog de ocr e document_processing" do
    stub_ocr(text: "LOJA X\nTOTAL 9,90", confidence: 80)
    doc = image_document

    Aionis::DocumentExtractionService.call(doc)

    ocr = AuditLog.where(action: "ocr", document_id: doc.id).last
    assert_not_nil ocr
    assert_equal "tesseract", ocr.provider
    assert_equal "ocr", ocr.origin

    proc_log = AuditLog.where(action: "document_processing", document_id: doc.id).last
    assert_not_nil proc_log
    assert_equal "tesseract", proc_log.provider
  end

  test "OCR indisponível (provider null) cai no placeholder" do
    # sem override: provider padrão é null -> unavailable
    doc = image_document
    ext = Aionis::DocumentExtractionService.call(doc)

    assert_equal "placeholder", ext.processor_name
    assert_equal 0, ext.confidence_score
    assert_match(/OCR\/IA/, ext.extracted_data["message"])
    assert_equal "review", doc.reload.status

    ocr = AuditLog.where(action: "ocr", document_id: doc.id).last
    assert_not_nil ocr, "deve registrar tentativa de OCR mesmo indisponível"
    assert_equal 0, ocr.confidence
  end

  test "OCR sem texto útil cai no placeholder" do
    stub_ocr(text: "   ", confidence: 10)
    doc = image_document
    ext = Aionis::DocumentExtractionService.call(doc)

    assert_equal "placeholder", ext.processor_name
  end

  test "XML fiscal continua roteando para o parser interno" do
    doc = xml_document
    ext = Aionis::DocumentExtractionService.call(doc)

    assert_equal "fiscal_xml_parser", ext.processor_name
    assert_equal "extracted", ext.status
    assert_equal "review", doc.reload.status
  end

  test "erro inesperado deixa o documento em failed" do
    doc = image_document
    # Força erro no meio do processamento
    Aionis::Integrations.override(:ocr, Object.new) # não responde a extract
    ext = Aionis::DocumentExtractionService.call(doc)

    assert_equal "failed", ext.status
    assert_equal "failed", doc.reload.status
  end
end
