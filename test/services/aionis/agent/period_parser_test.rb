require "test_helper"

class Aionis::Agent::PeriodParserTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 7, 22)

  def parse(text) = Aionis::Agent::PeriodParser.call(text, today: TODAY)

  test "vazio usa o mês atual" do
    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 7, 31), parse(nil)
    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 7, 31), parse("")
  end

  test "períodos fixos" do
    assert_equal TODAY..TODAY, parse("hoje")
    assert_equal (TODAY - 1)..(TODAY - 1), parse("ontem")
    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 7, 31), parse("esse mês")
    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 7, 31), parse("Este Mês")
    assert_equal Date.new(2026, 6, 1)..Date.new(2026, 6, 30), parse("mês passado")
    assert_equal Date.new(2026, 1, 1)..Date.new(2026, 12, 31), parse("esse ano")
    assert_equal Date.new(2025, 1, 1)..Date.new(2025, 12, 31), parse("ano passado")
  end

  test "últimos N dias" do
    assert_equal Date.new(2026, 6, 23)..TODAY, parse("últimos 30 dias")
    assert_equal Date.new(2026, 7, 16)..TODAY, parse("ultimos 7 dias")
  end

  test "mês por nome assume o mais recente já ocorrido" do
    assert_equal Date.new(2026, 1, 1)..Date.new(2026, 1, 31), parse("janeiro")
    # setembro ainda não chegou em 2026 → usa 2025
    assert_equal Date.new(2025, 9, 1)..Date.new(2025, 9, 30), parse("setembro")
    assert_equal Date.new(2025, 1, 1)..Date.new(2025, 1, 31), parse("janeiro de 2025")
    assert_equal Date.new(2026, 3, 1)..Date.new(2026, 3, 31), parse("março/2026")
    assert_equal Date.new(2026, 2, 1)..Date.new(2026, 2, 28), parse("02/2026")
  end

  test "entrada desconhecida devolve nil (nunca chuta)" do
    assert_nil parse("quando a lua estiver cheia")
    assert_nil parse("13/2026")
  end
end
