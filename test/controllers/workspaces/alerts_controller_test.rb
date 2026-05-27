require "test_helper"

class Workspaces::AlertsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Alerts Tester",
      email: "alerts_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Alerts", kind: "empresa", owner: @user)
    sign_in @user
  end

  def make_payable(due_on:, **extra)
    @workspace.financial_transactions.create!({
      kind: "expense", description: "Conta a pagar teste",
      amount_cents: 10_000, origin: "manual", status: "pending",
      settlement_status: "open", due_on: due_on
    }.merge(extra))
  end

  def make_receivable(due_on:, **extra)
    @workspace.financial_transactions.create!({
      kind: "income", description: "Conta a receber teste",
      amount_cents: 10_000, origin: "manual", status: "pending",
      settlement_status: "open", due_on: due_on
    }.merge(extra))
  end

  def make_doc(status:)
    d = @workspace.documents.new(source: "web", status: status)
    d.save!(validate: false)
    d
  end

  def make_tx(kind: "expense", amount_cents: 5_000, status: "confirmed", **extra)
    @workspace.financial_transactions.create!(
      kind: kind, description: "lançamento #{kind}",
      amount_cents: amount_cents, origin: "manual", status: status,
      **extra
    )
  end

  # 1. Acessa página de alertas
  test "GET index retorna sucesso" do
    get workspace_alerts_path(@workspace)
    assert_response :success
  end

  # 2. Estado vazio quando não há pendências
  test "exibe mensagem Tudo em dia quando não há alertas" do
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Tudo em dia", response.body
  end

  # 3. Conta a pagar vencida aparece como crítico
  test "conta a pagar vencida aparece como alerta crítico" do
    make_payable(due_on: Date.current - 1)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Contas a pagar vencidas", response.body
    assert_match "Crítico", response.body
  end

  # 4. Conta a receber vencida aparece como crítico
  test "conta a receber vencida aparece como alerta crítico" do
    make_receivable(due_on: Date.current - 1)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Contas a receber vencidas", response.body
    assert_match "Crítico", response.body
  end

  # 5a. Conta a pagar vencendo em 3 dias aparece como atenção
  test "conta a pagar vencendo em 3 dias aparece como atenção" do
    make_payable(due_on: Date.current + 2)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Contas a pagar vencem em breve", response.body
    assert_match "Atenção", response.body
  end

  # 5b. Conta a pagar vencendo em 7 dias aparece como atenção
  test "conta a pagar vencendo em 7 dias aparece como atenção" do
    make_payable(due_on: Date.current + 6)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Contas a pagar em 4 a 7 dias", response.body
    assert_match "Atenção", response.body
  end

  # 6a. Conta a receber vencendo em 3 dias aparece como atenção
  test "conta a receber vencendo em 3 dias aparece como atenção" do
    make_receivable(due_on: Date.current + 2)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Contas a receber vencem em breve", response.body
    assert_match "Atenção", response.body
  end

  # 6b. Conta a receber vencendo em 7 dias aparece como informativo
  test "conta a receber vencendo em 7 dias aparece como informativo" do
    make_receivable(due_on: Date.current + 6)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Contas a receber em 4 a 7 dias", response.body
    assert_match "Informativo", response.body
  end

  # 7. Documento pending aparece como informativo
  test "documento pendente aparece como informativo" do
    make_doc(status: "pending")
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Documentos pendentes", response.body
    assert_match "Informativo", response.body
  end

  # 8. Documento review aparece como atenção
  test "documento em revisão aparece como atenção" do
    make_doc(status: "review")
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Documentos em revisão", response.body
    assert_match "Atenção", response.body
  end

  # 9. Documento failed aparece como crítico
  test "documento com falha aparece como alerta crítico" do
    make_doc(status: "failed")
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Documentos com falha", response.body
    assert_match "Crítico", response.body
  end

  # 10. Lançamento pending aparece como atenção
  test "lançamento pendente aparece como atenção" do
    make_tx(status: "pending")
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Lançamentos pendentes", response.body
    assert_match "Atenção", response.body
  end

  # 11. Lançamento sem categoria aparece como informativo
  test "lançamento sem categoria aparece como informativo" do
    make_tx(status: "confirmed", category: nil)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Lançamentos sem categoria", response.body
    assert_match "Informativo", response.body
  end

  # 12. Lançamento sem fornecedor/cliente aparece como informativo
  test "lançamento sem fornecedor aparece como informativo" do
    make_tx(status: "confirmed", counterparty: nil)
    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Lançamentos sem fornecedor/cliente", response.body
    assert_match "Informativo", response.body
  end

  # 13. Settled não aparece como pendência de pagamento
  test "conta liquidada não aparece como vencida" do
    t = make_payable(due_on: Date.current - 1)
    t.settle!

    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_no_match "Contas a pagar vencidas", response.body
  end

  # 14. Cancelled não aparece como pendência
  test "lançamento cancelado não aparece como pendência" do
    make_tx(status: "cancelled")

    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Tudo em dia", response.body
  end

  # 15. Dados de outro workspace não aparecem
  test "não exibe alertas de outro workspace" do
    other_user = User.create!(
      name: "Outro",
      email: "other_alerts_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Outro", kind: "cpf", owner: other_user)
    other_ws.financial_transactions.create!(
      kind: "expense", description: "Conta alheia vencida",
      amount_cents: 999_999, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current - 1
    )

    get workspace_alerts_path(@workspace)
    assert_response :success
    assert_match "Tudo em dia", response.body
  end
end
