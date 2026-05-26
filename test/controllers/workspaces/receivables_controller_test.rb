require "test_helper"

class Workspaces::ReceivablesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Receivable Tester",
      email: "receivable_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Receivable", kind: "empresa", owner: @user)
    sign_in @user
  end

  def make_receivable(attrs = {})
    @workspace.financial_transactions.create!({
      kind:              "income",
      description:       "Cobrança teste",
      amount_cents:      20_000,
      origin:            "manual",
      status:            "pending",
      settlement_status: "open",
      due_on:            Date.current + 7
    }.merge(attrs))
  end

  # 1. Index acessível
  test "GET index retorna sucesso" do
    get workspace_receivables_path(@workspace)
    assert_response :success
  end

  # 2. Index mostra apenas receitas com settlement_status presente
  test "index exibe contas a receber do workspace" do
    make_receivable(description: "Fatura cliente XYZ")
    @workspace.financial_transactions.create!(
      kind: "income", description: "Receita avulsa",
      amount_cents: 5_000, origin: "manual", status: "confirmed"
    )

    get workspace_receivables_path(@workspace)
    assert_response :success
    assert_match    "Fatura cliente XYZ", response.body
    assert_no_match "Receita avulsa",     response.body
  end

  # 3. Novo formulário acessível
  test "GET new retorna sucesso" do
    get new_workspace_receivable_path(@workspace)
    assert_response :success
  end

  # 4. Cria conta a receber com dados válidos
  test "POST create cria conta a receber e redireciona para show" do
    assert_difference "@workspace.financial_transactions.receivables.count", 1 do
      post workspace_receivables_path(@workspace), params: {
        financial_transaction: {
          description: "Serviço de consultoria",
          amount_brl:  "800,00",
          due_on:      (Date.current + 10).to_s
        }
      }
    end

    created = @workspace.financial_transactions.receivables.last
    assert_equal "income",  created.kind
    assert_equal "open",    created.settlement_status
    assert_equal "manual",  created.origin
    assert_redirected_to workspace_receivable_path(@workspace, created)
  end

  # 5. Criação falha sem descrição
  test "POST create falha sem descrição" do
    assert_no_difference "@workspace.financial_transactions.receivables.count" do
      post workspace_receivables_path(@workspace), params: {
        financial_transaction: { amount_brl: "200,00", due_on: Date.current.to_s }
      }
    end
    assert_response :unprocessable_entity
  end

  # 6. Show acessível
  test "GET show retorna sucesso" do
    r = make_receivable
    get workspace_receivable_path(@workspace, r)
    assert_response :success
    assert_match r.description, response.body
  end

  # 7. Edit acessível
  test "GET edit retorna sucesso para conta aberta" do
    r = make_receivable
    get edit_workspace_receivable_path(@workspace, r)
    assert_response :success
  end

  # 8. Update salva alterações
  test "PATCH update atualiza descrição" do
    r = make_receivable(description: "Descrição original")
    patch workspace_receivable_path(@workspace, r), params: {
      financial_transaction: { description: "Descrição atualizada", due_on: r.due_on.to_s }
    }
    assert_redirected_to workspace_receivable_path(@workspace, r)
    assert_equal "Descrição atualizada", r.reload.description
  end

  # 9. Settle: marca como recebido
  test "PATCH settle liquida conta aberta" do
    r = make_receivable
    patch settle_workspace_receivable_path(@workspace, r)

    assert_redirected_to workspace_receivable_path(@workspace, r)
    r.reload
    assert_equal "settled",   r.settlement_status
    assert_equal "confirmed", r.status
    assert_not_nil            r.settled_on
  end

  # 10. Settle em conta já liquidada não altera
  test "PATCH settle em conta já liquidada redireciona com alerta" do
    r = make_receivable
    r.settle!

    patch settle_workspace_receivable_path(@workspace, r)
    assert_redirected_to workspace_receivable_path(@workspace, r)
    assert_equal "settled", r.reload.settlement_status
  end

  # 11. Destroy: exclui conta aberta
  test "DELETE destroy exclui conta aberta" do
    r = make_receivable
    assert_difference "@workspace.financial_transactions.count", -1 do
      delete workspace_receivable_path(@workspace, r)
    end
    assert_redirected_to workspace_receivables_path(@workspace)
  end

  # 12. Destroy: conta liquidada vira cancelled
  test "DELETE destroy em conta liquidada cancela em vez de excluir" do
    r = make_receivable
    r.settle!

    assert_no_difference "@workspace.financial_transactions.count" do
      delete workspace_receivable_path(@workspace, r)
    end

    assert_redirected_to workspace_receivables_path(@workspace)
    assert_equal "cancelled", r.reload.settlement_status
  end

  # 13. Isolamento: não acessa conta de outro workspace
  test "GET show de outro workspace retorna 404" do
    other_user = User.create!(
      name: "Outro",
      email: "other_rec_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Outro", kind: "cpf", owner: other_user)
    other_r = other_ws.financial_transactions.create!(
      kind: "income", description: "Receita alheia",
      amount_cents: 5_000, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current + 3
    )

    get workspace_receivable_path(@workspace, other_r)
    assert_response :not_found
  end
end
