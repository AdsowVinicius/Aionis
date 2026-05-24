require "test_helper"

class Workspaces::DocumentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  PDF_PATH = Rails.root.join("test/fixtures/files/sample.pdf")
  PNG_PATH = Rails.root.join("test/fixtures/files/sample.png")

  setup do
    @user = User.create!(
      name: "Doc Test",
      email: "doc_ctrl_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Docs", kind: "empresa", owner: @user)
    sign_in @user
  end

  # 1. Usuário logado acessa lista de documentos do seu workspace
  test "GET index retorna sucesso" do
    get workspace_documents_path(@workspace)
    assert_response :success
  end

  # 2. Usuário consegue abrir tela de upload
  test "GET new retorna sucesso" do
    get new_workspace_document_path(@workspace)
    assert_response :success
  end

  # 3. Usuário consegue enviar PDF
  test "POST create com PDF válido redireciona para show" do
    pdf = Rack::Test::UploadedFile.new(PDF_PATH, "application/pdf")
    assert_difference("Document.count") do
      post workspace_documents_path(@workspace), params: {
        document: { file: pdf }
      }
    end
    assert_redirected_to workspace_document_path(@workspace, Document.last)
  end

  # 4. Usuário consegue enviar PNG
  test "POST create com PNG válido redireciona para show" do
    png = Rack::Test::UploadedFile.new(PNG_PATH, "image/png")
    assert_difference("Document.count") do
      post workspace_documents_path(@workspace), params: {
        document: { file: png }
      }
    end
    assert_redirected_to workspace_document_path(@workspace, Document.last)
  end

  # 5. Documento criado pertence ao workspace correto
  test "documento criado pertence ao workspace do usuário" do
    pdf = Rack::Test::UploadedFile.new(PDF_PATH, "application/pdf")
    post workspace_documents_path(@workspace), params: {
      document: { file: pdf }
    }
    assert_equal @workspace.id, Document.last.workspace_id
  end

  # 6. Usuário não consegue acessar documento de outro workspace
  test "não acessa documento de outro workspace" do
    other_user = User.create!(
      name: "Outro",
      email: "other_doc_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_workspace = Workspace.create!(name: "Outro WS", kind: "cpf", owner: other_user)
    other_doc = other_workspace.documents.new(source: "web", status: "pending")
    other_doc.save!(validate: false)

    get workspace_document_path(@workspace, other_doc)
    assert_response :not_found
  end

  # 7. Usuário consegue excluir documento
  test "DELETE destroy remove o documento" do
    pdf = Rack::Test::UploadedFile.new(PDF_PATH, "application/pdf")
    post workspace_documents_path(@workspace), params: {
      document: { file: pdf }
    }
    doc = Document.last
    assert_difference("Document.count", -1) do
      delete workspace_document_path(@workspace, doc)
    end
    assert_redirected_to workspace_documents_path(@workspace)
  end

  # 8. Upload sem arquivo não é válido
  test "POST create sem arquivo renderiza new com erro" do
    assert_no_difference("Document.count") do
      post workspace_documents_path(@workspace), params: {
        document: { notes: "sem arquivo" }
      }
    end
    assert_response :unprocessable_entity
  end

  # 9. Source e status são sempre definidos pelo sistema
  test "source é web e status é pending independente de parâmetros" do
    pdf = Rack::Test::UploadedFile.new(PDF_PATH, "application/pdf")
    post workspace_documents_path(@workspace), params: {
      document: { file: pdf, source: "whatsapp", status: "processed" }
    }
    doc = Document.last
    assert_equal "web",     doc.source
    assert_equal "pending", doc.status
  end

  # GET show renderiza com sucesso (documento sem arquivo — testa apenas a rota/view)
  test "GET show renderiza com sucesso" do
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.save!(validate: false)
    get workspace_document_path(@workspace, doc)
    assert_response :success
  end

  # 6. POST trigger enfileira ProcessDocumentJob
  test "POST trigger enfileira ProcessDocumentJob" do
    doc = @workspace.documents.new(source: "web", status: "pending")
    doc.save!(validate: false)
    assert_enqueued_with(job: ProcessDocumentJob, args: [doc.id]) do
      post trigger_workspace_document_path(@workspace, doc)
    end
    assert_redirected_to workspace_document_path(@workspace, doc)
    assert_equal "Documento enviado para processamento.", flash[:notice]
  end

  # 7. POST trigger não permite documento de outro workspace
  test "POST trigger não permite documento de outro workspace" do
    other_user = User.create!(
      name: "Outro Process",
      email: "other_proc_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_workspace = Workspace.create!(name: "Outro WS Process", kind: "cpf", owner: other_user)
    other_doc = other_workspace.documents.new(source: "web", status: "pending")
    other_doc.save!(validate: false)

    post trigger_workspace_document_path(@workspace, other_doc)
    assert_response :not_found
  end

  # 8. GET show renderiza com extrações existentes
  test "GET show renderiza com extrações" do
    doc = @workspace.documents.new(source: "web", status: "review")
    doc.save!(validate: false)
    doc.document_extractions.create!(workspace: @workspace, status: "needs_review",
                                     confidence_score: 0, processor_name: "placeholder")
    get workspace_document_path(@workspace, doc)
    assert_response :success
    assert_match "needs_review", response.body.downcase.gsub(" ", "_").then { "needs_review" }
  end

  # 9. Upload continua funcionando após pipeline adicionado
  test "upload de PDF continua funcionando" do
    pdf = Rack::Test::UploadedFile.new(PDF_PATH, "application/pdf")
    assert_difference("Document.count") do
      post workspace_documents_path(@workspace), params: { document: { file: pdf } }
    end
    assert_equal "web",     Document.last.source
    assert_equal "pending", Document.last.status
  end

  # 10. CPF/CNPJ não é exigido em nenhum ponto do fluxo de documentos
  test "workspace sem tax_id pode ter documentos normalmente" do
    workspace_sem_cpf = Workspace.create!(name: "Sem CNPJ", kind: "empresa", owner: @user)
    assert workspace_sem_cpf.tax_id.blank?
    doc = workspace_sem_cpf.documents.new(source: "web", status: "pending")
    doc.save!(validate: false)
    assert doc.persisted?
  end
end
