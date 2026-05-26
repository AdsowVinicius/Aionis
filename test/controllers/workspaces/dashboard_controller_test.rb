require "test_helper"

class Workspaces::DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      name: "Dash Test",
      email: "dash_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Dash", kind: "empresa", owner: @user)
    sign_in @user
  end

  def tx(kind:, amount_cents:, status: "confirmed", transacted_on: Date.current, **extra)
    @workspace.financial_transactions.create!(
      kind: kind, description: "#{kind} #{amount_cents}",
      amount_cents: amount_cents, origin: "manual",
      status: status, transacted_on: transacted_on, **extra
    )
  end

  # 1. Dashboard acessível
  test "GET show retorna sucesso" do
    get workspace_dashboard_path(@workspace)
    assert_response :success
  end

  # 2. Receita do mês: soma apenas do mês corrente
  # Mês atual: 50_000 + 70_000 = 120_000 → R$ 1.200,00
  # Mês anterior (999_000) entra no saldo geral mas NÃO na receita do mês
  # O card "Receita do mês" mostrará exatamente "1.200,00"
  test "exibe receita do mês atual" do
    tx(kind: "income", amount_cents:  50_000)
    tx(kind: "income", amount_cents:  70_000)
    tx(kind: "income", amount_cents: 999_000, transacted_on: 2.months.ago.to_date)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "1.200,00", response.body
  end

  # 3. Despesa do mês: soma apenas do mês corrente
  # Mês atual: 80_000 → R$ 800,00
  # Mês anterior (550_000) vai para saldo geral, não para despesa do mês
  test "exibe despesa do mês atual" do
    tx(kind: "expense", amount_cents:  80_000)
    tx(kind: "expense", amount_cents: 550_000, transacted_on: 3.months.ago.to_date)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "800,00", response.body
  end

  # 4. Saldo do mês = receitas - despesas (200_000 - 75_000 = 125_000 → R$ 1.250,00)
  test "saldo do mês é receitas menos despesas" do
    tx(kind: "income",  amount_cents: 200_000)
    tx(kind: "expense", amount_cents:  75_000)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "1.250,00", response.body
  end

  # 5. Saldo geral acumula histórico além do mês corrente
  # 500_000 (3 meses atrás) - 200_000 (2 meses atrás) + 100_000 (este mês) = 400_000 → R$ 4.000,00
  test "saldo geral inclui lançamentos de meses anteriores" do
    tx(kind: "income",  amount_cents: 500_000, transacted_on: 3.months.ago.to_date)
    tx(kind: "expense", amount_cents: 200_000, transacted_on: 2.months.ago.to_date)
    tx(kind: "income",  amount_cents: 100_000)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "4.000,00", response.body  # saldo geral acumulado
    assert_match "1.000,00", response.body  # receita só deste mês
  end

  # 6. Lançamentos cancelled são excluídos de TODOS os KPIs financeiros
  # Confirmados: income 100_000 + expense 40_000 → saldo = 60_000 → R$ 600,00
  # Cancelados:  income 222_222 + expense 333_333 (não devem entrar em NENHUM cálculo)
  # Se cancelled fosse incluído, receita mensal seria R$ 3.222,22 — não pode aparecer
  test "cancelled não entram nos KPIs financeiros" do
    tx(kind: "income",  amount_cents: 100_000)
    tx(kind: "income",  amount_cents: 222_222, status: "cancelled")
    tx(kind: "expense", amount_cents:  40_000)
    tx(kind: "expense", amount_cents: 333_333, status: "cancelled")

    get workspace_dashboard_path(@workspace)
    assert_response :success
    # Valores corretos devem aparecer
    assert_match "1.000,00", response.body  # receita real do mês
    assert_match "400,00",   response.body  # despesa real do mês
    # Somas que só apareceriam se cancelled fosse incluído NÃO devem aparecer
    # Note: general_balance também exclui cancelled, logo esses totais nunca aparecem
    assert_no_match "3.222,22", response.body  # receita com cancelled = 3.222,22
    assert_no_match "3.733,33", response.body  # despesa com cancelled = 3.733,33
  end

  # 7. Conta documentos pendentes
  test "exibe seção de documentos pendentes" do
    2.times { d = @workspace.documents.new(source: "web", status: "pending"); d.save!(validate: false) }
    d = @workspace.documents.new(source: "web", status: "processed")
    d.save!(validate: false)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "Docs. pendentes", response.body
  end

  # 8. Conta documentos em revisão
  test "exibe seção de documentos em revisão" do
    d = @workspace.documents.new(source: "web", status: "review")
    d.save!(validate: false)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "Docs. em revisão", response.body
  end

  # 9. Conta lançamentos pendentes
  test "exibe seção de lançamentos pendentes" do
    tx(kind: "expense", amount_cents: 5_000, status: "pending")
    tx(kind: "expense", amount_cents: 5_000, status: "pending")
    tx(kind: "income",  amount_cents: 5_000, status: "confirmed")

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "Lançamentos pendentes", response.body
  end

  # 10. Top categorias de despesa do mês aparecem pelo nome
  test "exibe top categorias de despesa do mês" do
    cat_a = @workspace.categories.create!(name: "AluguelEspecialXYZ",  kind: "expense")
    cat_b = @workspace.categories.create!(name: "MaterialEspecialABC", kind: "expense")

    tx(kind: "expense", amount_cents: 200_000, category: cat_a)
    tx(kind: "expense", amount_cents:  50_000, category: cat_b)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "AluguelEspecialXYZ",  response.body
    assert_match "MaterialEspecialABC", response.body
  end

  # 11. Top fornecedores/clientes do mês aparecem pelo nome
  test "exibe top fornecedores do mês" do
    cp_a = @workspace.counterparties.create!(name: "FornecedorAlphaUnique", kind: "supplier")
    cp_b = @workspace.counterparties.create!(name: "ClienteBetaUnique",     kind: "client")

    tx(kind: "expense", amount_cents: 300_000, counterparty: cp_a)
    tx(kind: "income",  amount_cents: 100_000, counterparty: cp_b)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "FornecedorAlphaUnique", response.body
    assert_match "ClienteBetaUnique",     response.body
  end

  # 13. Conta a pagar em aberto NÃO entra nos KPIs de despesa realizada
  # open payable (311_111) não deve inflacionar a despesa do mês (40_000)
  # Se fosse incluída, o total seria 3.511,11 — isso não pode aparecer nos KPIs
  # Nota: o valor 3.111,11 pode aparecer nos alertas de contas a pagar (comportamento correto)
  test "conta a pagar aberta não entra na despesa realizada do mês" do
    tx(kind: "expense", amount_cents: 40_000)  # despesa real
    @workspace.financial_transactions.create!(
      kind: "expense", description: "Conta aberta",
      amount_cents: 311_111, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current + 5
    )

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match    "400,00",   response.body   # despesa realizada do mês
    assert_no_match "3.511,11", response.body   # soma errada se open fosse incluída nos KPIs
  end

  # 14. Conta a receber em aberto NÃO entra nos KPIs de receita realizada
  # open receivable (411_111) não deve inflacionar a receita do mês (60_000)
  # Se fosse incluída, o total seria 4.711,11 — isso não pode aparecer nos KPIs
  test "conta a receber aberta não entra na receita realizada do mês" do
    tx(kind: "income", amount_cents: 60_000)  # receita real
    @workspace.financial_transactions.create!(
      kind: "income", description: "Receita pendente",
      amount_cents: 411_111, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current + 3
    )

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match    "600,00",   response.body   # receita realizada do mês
    assert_no_match "4.711,11", response.body   # soma errada se open fosse incluída nos KPIs
  end

  # 15. Conta liquidada (settled) ENTRA nos KPIs como realizada
  test "conta liquidada entra nos KPIs como realizada" do
    p = @workspace.financial_transactions.create!(
      kind: "expense", description: "Conta liquidada",
      amount_cents: 55_000, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current - 1
    )
    p.settle!

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match "550,00", response.body  # despesa liquidada aparece
  end

  # 16. overdue? é true quando due_on < Date.current e settlement_status = open
  test "overdue? retorna true para conta vencida aberta" do
    t = @workspace.financial_transactions.new(
      kind: "expense", description: "Conta vencida",
      amount_cents: 10_000, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current - 1
    )
    assert t.overdue?
  end

  # 17. overdue? é false para conta futura
  test "overdue? retorna false para conta futura" do
    t = @workspace.financial_transactions.new(
      kind: "expense", description: "Conta futura",
      amount_cents: 10_000, origin: "manual", status: "pending",
      settlement_status: "open", due_on: Date.current + 5
    )
    assert_not t.overdue?
  end

  # 18. overdue? é false para conta liquidada mesmo com due_on passado
  test "overdue? retorna false para conta liquidada" do
    t = @workspace.financial_transactions.new(
      kind: "expense", description: "Conta paga",
      amount_cents: 10_000, origin: "manual", status: "confirmed",
      settlement_status: "settled", due_on: Date.current - 5
    )
    assert_not t.overdue?
  end

  # 12. Não mistura dados de outro workspace
  # Outro workspace: income 978_654 → R$ 9.786,54 (não deve aparecer)
  # Workspace atual: income 10_000 → R$ 100,00 (deve aparecer)
  test "não mistura dados de outro workspace" do
    other_user = User.create!(
      name: "Outro",
      email: "other_dash_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    other_ws = Workspace.create!(name: "WS Outro", kind: "cpf", owner: other_user)
    other_ws.financial_transactions.create!(
      kind: "income", description: "Receita alheia",
      amount_cents: 978_654, origin: "manual", status: "confirmed",
      transacted_on: Date.current
    )

    tx(kind: "income", amount_cents: 10_000)

    get workspace_dashboard_path(@workspace)
    assert_response :success
    assert_match    "100,00",   response.body  # valor do workspace atual
    assert_no_match "9.786,54", response.body  # valor do outro workspace não aparece
  end
end
