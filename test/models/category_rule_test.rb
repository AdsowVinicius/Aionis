require "test_helper"

class CategoryRuleTest < ActiveSupport::TestCase
  Ctx = Struct.new(:description, :kind, :counterparty_id, :tax_id_digits, keyword_init: true)

  def ctx(description: "", kind: "expense", counterparty_id: nil, tax_id_digits: nil)
    Ctx.new(description: description, kind: kind, counterparty_id: counterparty_id, tax_id_digits: tax_id_digits)
  end

  test "keyword_list normaliza minúsculas e remove acentos" do
    rule = CategoryRule.new(name: "R", keywords: "Combustível, GASOLINA ,  ")
    assert_equal ["combustivel", "gasolina"], rule.keyword_list
  end

  test "match por palavra-chave ignora acento e caixa" do
    rule = CategoryRule.new(name: "R", keywords: "combustivel")
    assert rule.matches?(ctx(description: "Compra de COMBUSTÍVEL no posto"))
    assert_not rule.matches?(ctx(description: "Compra de material"))
  end

  test "regra sem nenhuma condição nunca casa" do
    rule = CategoryRule.new(name: "Vazia")
    assert_not rule.matches?(ctx(description: "qualquer coisa"))
  end

  test "condições são combinadas com AND" do
    rule = CategoryRule.new(name: "R", keywords: "energia", kind: "expense")
    assert rule.matches?(ctx(description: "conta de energia", kind: "expense"))
    assert_not rule.matches?(ctx(description: "conta de energia", kind: "income"))
  end

  test "match por tax_id compara apenas dígitos" do
    rule = CategoryRule.new(name: "R", tax_id: "11.222.333/0001-81")
    assert rule.matches?(ctx(tax_id_digits: "11222333000181"))
    assert_not rule.matches?(ctx(tax_id_digits: "99999999999999"))
  end

  test "match_strength pontua condições satisfeitas" do
    rule = CategoryRule.new(name: "R", keywords: "gasolina", kind: "expense", counterparty_id: 5)
    c = ctx(description: "gasolina", kind: "expense", counterparty_id: 5)
    # kind(1) + counterparty(2) + keyword(1) = 4
    assert_equal 4, rule.match_strength(c)
  end

  test "validações de inclusão são opcionais mas rejeitam valores inválidos" do
    rule = CategoryRule.new(name: "R", scope: "invalido")
    assert_not rule.valid?
    assert_includes rule.errors.attribute_names, :scope

    ok = CategoryRule.new(name: "R", scope: "business", confidence: 70)
    assert ok.valid?
  end

  test "for_workspace inclui regras globais e do próprio workspace" do
    user = User.create!(name: "U", email: "cr_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    ws   = Workspace.create!(name: "WS", kind: "empresa", owner: user)
    other = Workspace.create!(name: "WS2", kind: "empresa", owner: user)

    g  = CategoryRule.create!(name: "Global", keywords: "x", workspace_id: nil)
    w  = CategoryRule.create!(name: "Do WS", keywords: "x", workspace: ws)
    _o = CategoryRule.create!(name: "Outro WS", keywords: "x", workspace: other)

    ids = CategoryRule.for_workspace(ws).pluck(:id)
    assert_includes ids, g.id
    assert_includes ids, w.id
    assert_not_includes ids, _o.id
  end
end
