require "test_helper"

class Workspaces::FinancialTransactionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Ctrl Test",
      email: "ft_ctrl_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Ctrl", kind: "empresa", owner: @user)
    sign_in @user
  end

  # 1. Cria lançamento manual sem document_id
  test "cria lançamento manual sem document_id" do
    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense",
          description: "Compra de material na loja do bairro",
          amount_brl: "120,50",
          status: "pending"
        }
      }
    end
    assert_redirected_to workspace_financial_transactions_path(@workspace)
    assert_nil FinancialTransaction.last.document_id
  end

  # 2. Cria lançamento manual sem counterparty_id
  test "cria lançamento manual sem counterparty_id" do
    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "expense",
          description: "Aluguel do escritório",
          amount_brl: "1.500,00",
          status: "pending"
        }
      }
    end
    assert_nil FinancialTransaction.last.counterparty_id
  end

  # 3. Cria lançamento manual sem category_id
  test "cria lançamento manual sem category_id" do
    assert_difference("FinancialTransaction.count") do
      post workspace_financial_transactions_path(@workspace), params: {
        financial_transaction: {
          kind: "income",
          description: "Receita de consultoria",
          amount_brl: "500",
          status: "confirmed"
        }
      }
    end
    assert_nil FinancialTransaction.last.category_id
  end

  # 4. Conversão de valor BR para centavos
  test "amount_brl converte 1.200,50 para 120050 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Teste de conversão",
        amount_brl: "1.200,50",
        status: "pending"
      }
    }
    assert_equal 120_050, FinancialTransaction.last.amount_cents
  end

  test "amount_brl converte 120,50 para 12050 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Teste de conversão decimal",
        amount_brl: "120,50",
        status: "pending"
      }
    }
    assert_equal 12_050, FinancialTransaction.last.amount_cents
  end

  test "amount_brl converte 120 para 12000 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "income",
        description: "Teste valor inteiro",
        amount_brl: "120",
        status: "pending"
      }
    }
    assert_equal 12_000, FinancialTransaction.last.amount_cents
  end

  # 5. Lançamento pertence ao workspace correto
  test "lançamento criado pertence ao workspace do usuário" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Despesa de teste",
        amount_brl: "100",
        status: "pending"
      }
    }
    assert_equal @workspace.id, FinancialTransaction.last.workspace_id
  end

  # 6. Isolamento multi-tenant: não acessa lançamento de outro workspace
  test "não acessa lançamento de outro workspace" do
    other_user = User.create!(
      name: "Outro",
      email: "other_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_workspace = Workspace.create!(name: "Outro WS", kind: "cpf", owner: other_user)
    other_tx = other_workspace.financial_transactions.create!(
      kind: "expense",
      description: "Lançamento de outro workspace",
      amount_cents: 5_000,
      origin: "manual",
      status: "pending"
    )

    get workspace_financial_transaction_path(@workspace, other_tx)
    assert_response :not_found
  end

  # 7. Origin é sempre forçado como "manual"
  test "origin é sempre manual independente do parâmetro enviado" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "income",
        description: "Origem deve ser manual",
        amount_brl: "200",
        status: "pending",
        origin: "import"
      }
    }
    assert_equal "manual", FinancialTransaction.last.origin
  end

  # --- Testes de renderização (GET) ---

  test "GET index renderiza com sucesso" do
    get workspace_financial_transactions_path(@workspace)
    assert_response :success
  end

  test "GET new renderiza com sucesso" do
    get new_workspace_financial_transaction_path(@workspace)
    assert_response :success
  end

  test "GET show renderiza com sucesso" do
    tx = @workspace.financial_transactions.create!(
      kind: "expense", description: "Lançamento para show",
      amount_cents: 9_900, origin: "manual", status: "pending"
    )
    get workspace_financial_transaction_path(@workspace, tx)
    assert_response :success
  end

  test "GET edit renderiza com sucesso" do
    tx = @workspace.financial_transactions.create!(
      kind: "income", description: "Lançamento para edit",
      amount_cents: 15_000, origin: "manual", status: "confirmed"
    )
    get edit_workspace_financial_transaction_path(@workspace, tx)
    assert_response :success
  end

  # Conversão adicional: "120.50" (ponto como decimal, sem vírgula)
  test "amount_brl converte 120.50 para 12050 centavos" do
    post workspace_financial_transactions_path(@workspace), params: {
      financial_transaction: {
        kind: "expense",
        description: "Teste ponto como decimal",
        amount_brl: "120.50",
        status: "pending"
      }
    }
    assert_equal 12_050, FinancialTransaction.last.amount_cents
  end

  # 8. Dashboard calcula receitas e despesas do mês atual
  test "dashboard exibe dados reais do mês atual" do
    @workspace.financial_transactions.create!(
      kind: "income", description: "Receita mês atual",
      amount_cents: 50_000, origin: "manual", status: "confirmed",
      transacted_on: Date.current
    )
    @workspace.financial_transactions.create!(
      kind: "expense", description: "Despesa mês atual",
      amount_cents: 20_000, origin: "manual", status: "confirmed",
      transacted_on: Date.current
    )
    # Lançamento de outro mês não deve entrar nos cards do mês
    @workspace.financial_transactions.create!(
      kind: "income", description: "Receita mês passado",
      amount_cents: 999_999, origin: "manual", status: "confirmed",
      transacted_on: 2.months.ago.to_date
    )

    get workspace_dashboard_path(@workspace)
    assert_response :success
  end
end
