require "test_helper"

class DocumentExtractionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Extraction Test",
      email: "extraction_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Extraction", kind: "empresa", owner: @user)
    @document  = @workspace.documents.new(source: "web", status: "pending")
    @document.save!(validate: false)
  end

  # 1. DocumentExtraction válida pertence ao document e ao workspace correto
  test "válida quando workspace corresponde ao documento" do
    ext = DocumentExtraction.new(
      workspace: @workspace,
      document:  @document,
      status:    "pending"
    )
    assert ext.valid?, ext.errors.full_messages.to_s
  end

  # 2. Inválida quando workspace_id difere do workspace do documento
  test "inválida quando workspace não corresponde ao documento" do
    other_user = User.create!(
      name: "Outro",
      email: "other_ext_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_workspace = Workspace.create!(name: "Outro WS", kind: "cpf", owner: other_user)

    ext = DocumentExtraction.new(
      workspace: other_workspace,
      document:  @document,
      status:    "pending"
    )
    assert_not ext.valid?
    assert_includes ext.errors[:workspace_id], "deve ser o mesmo workspace do documento"
  end

  # 3. latest_extraction retorna a extração mais recente
  test "latest_extraction retorna a extração mais recente" do
    first_ext = @document.document_extractions.create!(
      workspace: @workspace,
      status:    "needs_review"
    )
    # Garante created_at diferente
    second_ext = @document.document_extractions.create!(
      workspace: @workspace,
      status:    "failed"
    )
    # Recarrega associação
    @document.reload
    latest = @document.latest_extraction
    assert_equal second_ext.id, latest.id
  end

  # 4. Enums estão todos definidos
  test "enums de status estão definidos" do
    assert DocumentExtraction.statuses.key?("pending")
    assert DocumentExtraction.statuses.key?("processing")
    assert DocumentExtraction.statuses.key?("extracted")
    assert DocumentExtraction.statuses.key?("needs_review")
    assert DocumentExtraction.statuses.key?("failed")
  end
end
