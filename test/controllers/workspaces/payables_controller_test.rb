require "test_helper"

class Workspaces::PayablesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Payable Tester",
      email: "payable_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Payable", kind: "empresa", owner: @user)
    sign_in @user
  end

  def make_payable(attrs = {})
    @workspace.financial_transactions.create!({
      kind:              "expense",
      description:       "Conta teste",
      amount_cents:      10_000,
      origin:            "manual",
      status:            "pending",
      settlement_status: "open",
      due_on:            Date.current + 7
    }.merge(attrs))
  end

  # 1. Index acessível
  test "GET index retorna sucesso" do
    get workspace_payables_path(@workspace)
    assert_response :success
  end

  # 2. Index mostra apenas despesas com settlement_status presente
  test "index exibe contas a pagar do workspace" do
    make_payable(description: "Aluguel escritório")
    @workspace.financial_transactions.create!(
      kind: "expense", description: "Lançamento simples",
      amount_cents: 5_000, origin: "manual", status: "confirmed"
    )

    get workspace_payables_path(@workspace)
    assert_response :success
    assert_match "Aluguel escritório", response.body
    assert_no_match "Lançamento simples", response.body
  end

  # 3. Novo formulário acessível
  test "GET new retorna sucesso" do
    get new_workspace_payable_path(@workspace)
    assert_response :success
  end

  # 4. Cria conta a pagar com dados válidos
  test "POST create cria conta a pagar e redireciona para show" do
    assert_difference "@workspace.financial_transactions.payables.count", 1 do
      post workspace_payables_path(@workspace), params: {
        financial_transaction: {
          description: "Internet mensal",
          amount_brl:  "150,00",
          due_on:      (Date.current + 5).to_s
        }
      }
    end

    created = @workspace.financial_transactions.payables.last
    assert_equal "expense",           created.kind
    assert_equal "open",              created.settlement_status
    assert_equal "manual",            created.origin
    assert_redirected_to workspace_payable_path(@workspace, created)
  end

  # 5. Criação falha sem descrição — fica na página new
  test "POST create falha sem descrição" do
    assert_no_difference "@workspace.financial_transactions.payables.count" do
      post workspace_payables_path(@workspace), params: {
        financial_transaction: { amount_brl: "50,00", due_on: Date.current.to_s }
      }
    end
    assert_response :unprocessable_entity
  end

  # 6. Show acessível
  test "GET show retorna sucesso" do
    p = make_payable
    get workspace_payable_path(@workspace, p)
    assert_response :success
    assert_match p.description, response.body
  end

  # 7. Edit acessível para conta aberta
  test "GET edit retorna sucesso para conta aberta" do
    p = make_payable
    get edit_workspace_payable_path(@workspace, p)
    assert_response :success
  end

  # 8. Update salva alterações
  test "PATCH update atualiza descrição" do
    p = make_payable(description: "Descrição original")
    patch workspace_payable_path(@workspace, p), params: {
      financial_transaction: { description: "Descrição alterada", due_on: p.due_on.to_s }
    }
    assert_redirected_to workspace_payable_path(@workspace, p)
    assert_equal "Descrição alterada", p.reload.description
  end

  # 9. Settle: marca como pago
  test "PATCH settle liquida conta aberta" do
    p = make_payable
    patch settle_workspace_payable_path(@workspace, p)

    assert_redirected_to workspace_payable_path(@workspace, p)
    p.reload
    assert_equal "settled",    p.settlement_status
    assert_equal "confirmed",  p.status
    assert_not_nil             p.settled_on
  end

  # 10. Settle em conta já liquidada não altera
  test "PATCH settle em conta já liquidada redireciona com alerta" do
    p = make_payable
    p.settle!

    patch settle_workspace_payable_path(@workspace, p)
    assert_redirected_to workspace_payable_path(@workspace, p)
    assert_equal "settled", p.reload.settlement_status
  end

  # 11. Destroy: exclui conta aberta
  test "DELETE destroy exclui conta aberta" do
    p = make_payable
    assert_difference "@workspace.financial_transactions.count", -1 do
      delete workspace_payable_path(@workspace, p)
    end
    assert_redirected_to workspace_payables_path(@workspace)
  end

  # 12. Destroy: conta liquidada vira cancelled (não exclui)
  test "DELETE destroy em conta liquidada cancela em vez de excluir" do
    p = make_payable
    p.settle!

    assert_no_difference "@workspace.financial_transactions.count" do
      delete workspace_payable_path(@workspace, p)
    end

    assert_redirected_to workspace_payables_path(@workspace)
    assert_equal "cancelled", p.reload.settlement_status
  end

  # 13. Isolamento: não acessa conta de outro workspace
  test "GET show de outro workspace retorna 404" do
    other_user = User.create!(
      name: "Outro",
      email: "other_pay_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Outro", kind: "cpf", owner: other_user)
    other_p = other_ws.financial_transactions.create!(
      kind: "expense", description: "Conta alheia",
      amount_cents: 5_000, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current + 3
    )

    get workspace_payable_path(@workspace, other_p)
    assert_response :not_found
  end
end
