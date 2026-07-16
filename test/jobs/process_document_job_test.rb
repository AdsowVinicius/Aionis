require "test_helper"

class ProcessDocumentJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  PDF_PATH = Rails.root.join("test/fixtures/files/sample.pdf")

  setup do
    @user = User.create!(
      name: "Job Test",
      email: "job_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Job", kind: "empresa", owner: @user)
    @document  = @workspace.documents.new(source: "web", status: "pending")
    @document.file.attach(
      io:           File.open(PDF_PATH),
      filename:     "sample.pdf",
      content_type: "application/pdf"
    )
    @document.save!
  end

  # 3. Job muda documento para processing e depois review
  test "muda documento para processing depois para review" do
    ProcessDocumentJob.perform_now(@document.id)
    @document.reload
    assert_equal "review", @document.status
  end

  # 4. Job cria uma DocumentExtraction
  test "cria uma DocumentExtraction" do
    assert_difference("DocumentExtraction.count", 1) do
      ProcessDocumentJob.perform_now(@document.id)
    end
  end

  # 5. Extraction termina como needs_review com confidence_score 0
  test "extraction termina como needs_review com confidence_score 0" do
    ProcessDocumentJob.perform_now(@document.id)
    ext = @document.document_extractions.last
    assert_not_nil ext
    assert_equal "needs_review", ext.status
    assert_equal 0, ext.confidence_score
  end

  # 5b. extracted_data contém mensagem sobre OCR/IA não implementado
  test "extracted_data contém mensagem sobre OCR/IA não implementado" do
    ProcessDocumentJob.perform_now(@document.id)
    ext = @document.document_extractions.last
    assert ext.extracted_data["message"].present?
    assert_match(/OCR\/IA/, ext.extracted_data["message"])
  end

  # 5c. Extraction tem processor_name placeholder e started_at/finished_at
  test "extraction tem processor_name placeholder e timestamps preenchidos" do
    ProcessDocumentJob.perform_now(@document.id)
    ext = @document.document_extractions.last
    assert_equal "placeholder", ext.processor_name
    assert_equal "0.1",         ext.processor_version
    assert_not_nil ext.started_at
    assert_not_nil ext.finished_at
  end

  # 5d. Extraction pertence ao workspace correto
  test "extraction pertence ao workspace do documento" do
    ProcessDocumentJob.perform_now(@document.id)
    ext = @document.document_extractions.last
    assert_equal @workspace.id, ext.workspace_id
  end

  # Job silenciosamente ignora document_id inexistente
  test "não falha quando document_id não existe" do
    assert_nothing_raised do
      ProcessDocumentJob.perform_now(999_999_999)
    end
    assert_equal 0, DocumentExtraction.count
  end

  # --- Pipeline de XML fiscal ---

  NFE_PATH = Rails.root.join("test/fixtures/files/sample_nfe.xml")

  def build_xml_document
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.file.attach(
      io:           File.open(NFE_PATH),
      filename:     "nfe.xml",
      content_type: "text/xml"
    )
    doc.save!
    doc
  end

  test "processa XML fiscal usando o parser interno" do
    doc = build_xml_document
    ProcessDocumentJob.perform_now(doc.id)
    ext = doc.document_extractions.last

    assert_equal "fiscal_xml_parser", ext.processor_name
    assert_equal "extracted", ext.status
    assert_equal 100, ext.confidence_score
    assert_equal "review", doc.reload.status
  end

  test "XML fiscal preenche suggested_transaction_data" do
    doc = build_xml_document
    ProcessDocumentJob.perform_now(doc.id)
    s = doc.document_extractions.last.suggested_transaction_data

    assert_equal "expense", s["kind"]
    assert_equal 15_000,    s["amount_cents"]
    assert_equal "2024-01-15", s["transacted_on"]
    assert_equal "Loja do Bairro Comercio LTDA", s["counterparty_name_snapshot"]
  end

  test "XML fiscal guarda dados extraidos com Date serializada" do
    doc = build_xml_document
    ProcessDocumentJob.perform_now(doc.id)
    data = doc.document_extractions.last.extracted_data

    assert_equal "2024-01-15", data["issued_on"]
    assert_equal 15_000,       data["amount_cents"]
  end

  test "XML nao fiscal fica em needs_review sem quebrar o job" do
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.file.attach(
      io:           StringIO.new("<foo><bar>x</bar></foo>"),
      filename:     "outro.xml",
      content_type: "application/xml"
    )
    doc.save!

    assert_nothing_raised { ProcessDocumentJob.perform_now(doc.id) }
    ext = doc.document_extractions.last
    assert_equal "needs_review", ext.status
    assert_equal "review", doc.reload.status
  end

  # --- Auditoria do processamento ---

  test "processamento de XML gera log document_processing" do
    doc = build_xml_document
    ProcessDocumentJob.perform_now(doc.id)

    log = AuditLog.where(action: "document_processing", document_id: doc.id).last
    assert_not_nil log
    assert_equal "job", log.origin
    assert_equal "fiscal_xml_parser", log.provider
    assert_equal doc.workspace_id, log.workspace_id
  end

  test "processamento de PDF gera log de OCR indisponível" do
    ProcessDocumentJob.perform_now(@document.id)

    ocr = AuditLog.where(action: "ocr", document_id: @document.id).last
    assert_not_nil ocr
    assert_equal "ocr", ocr.origin
    assert_equal 0, ocr.confidence
  end

  test "logs de job não têm usuário (origem sistema)" do
    ProcessDocumentJob.perform_now(@document.id)
    log = AuditLog.where(document_id: @document.id).last
    assert_nil log.user_id
  end
end
