require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "plano válido com campos obrigatórios" do
    plan = Plan.new(name: "Teste", slug: "teste", monthly_price_cents: 1000, status: "active")
    assert plan.valid?, plan.errors.full_messages.inspect
  end

  test "requer name" do
    plan = Plan.new(slug: "teste", monthly_price_cents: 0, status: "active")
    assert_not plan.valid?
    assert plan.errors[:name].any?
  end

  test "requer slug único" do
    Plan.create!(name: "P1", slug: "unico", monthly_price_cents: 0, status: "active")
    plan2 = Plan.new(name: "P2", slug: "unico", monthly_price_cents: 0, status: "active")
    assert_not plan2.valid?
    assert plan2.errors[:slug].any?
  end

  test "monthly_price_cents não pode ser negativo" do
    plan = Plan.new(name: "P", slug: "p-neg", monthly_price_cents: -1, status: "active")
    assert_not plan.valid?
    assert plan.errors[:monthly_price_cents].any?
  end

  test "monthly_price_brl converte centavos para reais" do
    plan = Plan.new(monthly_price_cents: 9700)
    assert_equal 97.0, plan.monthly_price_brl
  end
end
