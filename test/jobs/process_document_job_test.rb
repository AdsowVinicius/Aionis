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
end
