require "test_helper"

class Aionis::AnalyticsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "An", email: "an_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @ws = Workspace.create!(name: "WS Analytics", kind: "empresa", owner: @user)
  end

  def tx(kind:, cents:, on: Date.current, **extra)
    @ws.financial_transactions.create!(
      kind: kind, description: "x", amount_cents: cents, origin: "manual",
      status: "confirmed", transacted_on: on, **extra
    )
  end

  test "Kpis calcula mês e geral com taxa de poupança" do
    tx(kind: "income",  cents: 200_000)
    tx(kind: "expense", cents:  80_000)
    tx(kind: "income",  cents: 999_000, on: 2.months.ago.to_date)

    k = Aionis::Analytics::Kpis.call(@ws)
    assert_equal 200_000, k.income_cents
    assert_equal  80_000, k.expense_cents
    assert_equal 120_000, k.balance_cents
    assert_equal 1_199_000, k.general_income_cents
    assert_equal 1_119_000, k.general_balance_cents
    assert_equal 60.0, k.savings_rate
  end

  test "EssentialityBreakdown separa essenciais e supérfluos" do
    tx(kind: "expense", cents: 80_000, essentiality: "essential")
    tx(kind: "expense", cents: 40_000, essentiality: "superfluous")
    tx(kind: "expense", cents: 10_000, essentiality: "non_essential")

    e = Aionis::Analytics::EssentialityBreakdown.call(@ws)
    assert_equal 130_000, e.total_cents
    assert_equal  80_000, e.essential_cents
    assert_equal  50_000, e.superfluous_cents
    assert_in_delta 38.5, e.superfluous_ratio, 0.1
  end

  test "MonthlyEvolution retorna 12 meses com o mês corrente por último" do
    tx(kind: "income",  cents: 100_000)
    tx(kind: "expense", cents:  60_000)
    tx(kind: "income",  cents:  50_000, on: 1.month.ago.to_date)

    ev = Aionis::Analytics::MonthlyEvolution.call(@ws)
    assert_equal 12, ev.size
    assert_equal 100_000, ev.last[:income_cents]
    assert_equal  40_000, ev.last[:balance_cents]
  end

  test "CashFlow acumula o líquido" do
    tx(kind: "income",  cents: 100_000, on: 1.month.ago.to_date)
    tx(kind: "expense", cents:  40_000)
    cf = Aionis::Analytics::CashFlow.call(@ws)
    assert_equal cf.map { |m| m[:net_cents] }.sum, cf.last[:accumulated_cents]
  end

  test "BurnRate calcula consumo médio mensal" do
    3.times do |i|
      tx(kind: "expense", cents: 30_000, on: (i + 1).months.ago.to_date)
      tx(kind: "income",  cents: 10_000, on: (i + 1).months.ago.to_date)
    end
    b = Aionis::Analytics::BurnRate.call(@ws)
    assert_equal 20_000, b.monthly_burn_cents
  end

  test "Forecast projeta os próximos 3 meses" do
    tx(kind: "income",  cents: 100_000)
    tx(kind: "expense", cents:  60_000)
    f = Aionis::Analytics::Forecast.call(@ws)
    assert_equal 3, f.size
    assert f.first.key?(:projected_balance_cents)
  end

  test "Rankings top categorias, fornecedores e centros de custo" do
    cat_a = Category.create!(name: "Aluguel #{SecureRandom.hex(2)}", kind: "expense")
    cat_b = Category.create!(name: "Marketing #{SecureRandom.hex(2)}", kind: "expense")
    cp = @ws.counterparties.create!(name: "Fornecedor X", kind: "supplier")

    tx(kind: "expense", cents: 50_000, category: cat_a, counterparty: cp, cost_center: "Operações")
    tx(kind: "expense", cents: 30_000, category: cat_b, cost_center: "Marketing")

    r = Aionis::Analytics::Rankings.call(@ws)
    assert_equal cat_a.name, r[:categories].first[:name]
    assert_equal 50_000, r[:categories].first[:total_cents]
    assert_equal "Fornecedor X", r[:counterparties].first[:name]
    assert_equal "Operações", r[:cost_centers].first[:name]
  end

  test "AbcCurve classifica em A/B/C por acumulado" do
    a = Category.create!(name: "A #{SecureRandom.hex(2)}", kind: "expense")
    b = Category.create!(name: "B #{SecureRandom.hex(2)}", kind: "expense")
    c = Category.create!(name: "C #{SecureRandom.hex(2)}", kind: "expense")
    tx(kind: "expense", cents: 80_000, category: a)
    tx(kind: "expense", cents: 15_000, category: b)
    tx(kind: "expense", cents:  5_000, category: c)

    curve = Aionis::Analytics::AbcCurve.call(@ws)
    assert_equal "A", curve.first[:klass]
    assert_equal "C", curve.last[:klass]
    assert_in_delta 100.0, curve.last[:cumulative_pct], 0.1
  end

  test "HealthScore devolve score 0..100 e faixa" do
    tx(kind: "income",  cents: 200_000)
    tx(kind: "expense", cents:  80_000, essentiality: "essential")
    h = Aionis::Analytics::HealthScore.call(@ws)
    assert_includes 0..100, h.score
    assert_includes %w[healthy attention critical], h.band
  end

  test "Dashboard facade reúne todas as métricas" do
    tx(kind: "income", cents: 100_000)
    tx(kind: "expense", cents: 60_000)
    d = Aionis::Analytics::Dashboard.call(@ws)

    assert_kind_of Aionis::Analytics::Kpis::Result, d.kpis
    assert_equal 12, d.monthly_evolution.size
    assert_respond_to d.recent_transactions, :each
    assert_kind_of Array, d.insights
  end

  test "InsightGenerator gera insight de saldo negativo" do
    tx(kind: "income",  cents:  50_000)
    tx(kind: "expense", cents: 120_000)
    insights = Aionis::Analytics::InsightGenerator.new(@ws).build
    assert insights.any? { |i| i[:kind] == "negative_month_balance" }
  end

  test "SnapshotService persiste KpiSnapshot e é idempotente" do
    tx(kind: "income",  cents: 200_000)
    tx(kind: "expense", cents:  80_000)

    assert_difference -> { KpiSnapshot.count }, 1 do
      Aionis::Analytics::SnapshotService.call(@ws)
    end
    snap = @ws.kpi_snapshots.first
    assert_equal 200_000, snap.income_cents
    assert_equal Date.current.strftime("%Y-%m"), snap.period_label
    assert_not_nil snap.health_score

    assert_no_difference -> { KpiSnapshot.count } do
      Aionis::Analytics::SnapshotService.call(@ws)
    end
  end
end
