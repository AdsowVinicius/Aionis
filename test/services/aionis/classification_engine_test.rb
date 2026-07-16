require "test_helper"

class Aionis::ClassificationEngineTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Engine Test",
      email: "engine_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Engine", kind: "empresa", owner: @user)

    @fuel = Category.create!(name: "Combustível #{SecureRandom.hex(2)}", kind: "expense",
                             cost_type: "variable", essentiality: "review")
    @energy = Category.create!(name: "Energia #{SecureRandom.hex(2)}", kind: "expense",
                               cost_type: "fixed", essentiality: "essential")
  end

  def engine(description:, kind: "expense", counterparty_id: nil, tax_id: nil)
    Aionis::ClassificationEngine.new(
      workspace: @workspace, description: description, kind: kind,
      counterparty_id: counterparty_id, tax_id: tax_id
    )
  end

  test "regra por palavra-chave sugere categoria com cost_type e essentiality da categoria" do
    CategoryRule.create!(name: "Combustível global", keywords: "posto, gasolina, combustivel",
                         kind: "expense", category: @fuel, recurrence: "occasional", confidence: 78)

    s = engine(description: "Abastecimento no Posto Shell gasolina").call
    assert_equal @fuel.id, s.category_id
    assert_equal "variable", s.cost_type
    assert_equal "review",   s.essentiality
    assert_equal "occasional", s.recurrence
    assert_equal "rule", s.source
    assert_operator s.confidence, :>=, 61
  end

  test "casa palavra-chave presente apenas no extra_text (OCR bruto)" do
    CategoryRule.create!(name: "Farmácia", keywords: "dipirona, paracetamol",
                         kind: "expense", category: @fuel, confidence: 75)

    # Descrição não contém a palavra-chave; o extra_text (texto do OCR) contém.
    s = Aionis::ClassificationEngine.new(
      workspace: @workspace, description: "Drogaria SP — Documento digitalizado",
      kind: "expense", extra_text: "DROGARIA SP\nDipirona 500mg\nTOTAL 12,00"
    ).call

    assert_equal @fuel.id, s.category_id
    assert_equal "rule", s.source
  end

  test "sem extra_text, palavra-chave fora da descrição não casa" do
    CategoryRule.create!(name: "Farmácia", keywords: "dipirona",
                         kind: "expense", category: @fuel, confidence: 75)

    s = Aionis::ClassificationEngine.new(
      workspace: @workspace, description: "Drogaria SP", kind: "expense"
    ).call

    assert_nil s.category_id
  end

  test "não casa quando kind diverge" do
    CategoryRule.create!(name: "Só despesa", keywords: "gasolina", kind: "expense", category: @fuel)
    s = engine(description: "gasolina", kind: "income").call
    assert_nil s.category_id
    assert_equal "none", s.source
  end

  test "regra do workspace tem prioridade sobre a global" do
    CategoryRule.create!(name: "Global energia", keywords: "energia", kind: "expense",
                         category: @fuel, priority: 90, workspace_id: nil)
    CategoryRule.create!(name: "WS energia", keywords: "energia", kind: "expense",
                         category: @energy, priority: 10, workspace: @workspace)

    s = engine(description: "conta de energia").call
    assert_equal @energy.id, s.category_id, "regra do workspace deve vencer mesmo com prioridade menor"
  end

  test "match por CPF/CNPJ do fornecedor" do
    CategoryRule.create!(name: "Por CNPJ", tax_id: "11.222.333/0001-81",
                         category: @energy, confidence: 80, workspace: @workspace)

    s = engine(description: "qualquer coisa", tax_id: "11222333000181").call
    assert_equal @energy.id, s.category_id
    # match forte (tax_id vale 2 de strength) aumenta a confiança
    assert_operator s.confidence, :>=, 80
  end

  test "sem regra usa histórico do fornecedor" do
    cp = @workspace.counterparties.create!(name: "Fornecedor X", kind: "supplier")
    3.times do
      @workspace.financial_transactions.create!(
        kind: "expense", description: "compra", amount_cents: 1000, origin: "manual",
        status: "confirmed", counterparty: cp, category: @energy
      )
    end

    s = engine(description: "compra sem palavra-chave conhecida", counterparty_id: cp.id).call
    assert_equal @energy.id, s.category_id
    assert_equal "history", s.source
    assert_operator s.confidence, :>, 60
  end

  test "regra confirmada pelo histórico aumenta a confiança" do
    cp = @workspace.counterparties.create!(name: "Posto ABC", kind: "supplier")
    CategoryRule.create!(name: "Combustível", keywords: "gasolina", kind: "expense",
                         category: @fuel, confidence: 70)
    2.times do
      @workspace.financial_transactions.create!(
        kind: "expense", description: "gasolina", amount_cents: 1000, origin: "manual",
        status: "confirmed", counterparty: cp, category: @fuel
      )
    end

    s = engine(description: "gasolina posto", counterparty_id: cp.id).call
    assert_equal "rule+history", s.source
    assert_operator s.confidence, :>, 70
  end

  test "sem regra e sem histórico retorna sugestão vazia de baixa confiança" do
    s = engine(description: "descricao totalmente desconhecida xyz").call
    assert_nil s.category_id
    assert_equal 0, s.confidence
    assert_equal "none", s.source
    assert s.low_confidence?
    assert_not s.auto_applicable?
  end

  test "for_transaction extrai contexto do lançamento (incluindo tax_id do fornecedor)" do
    cp = @workspace.counterparties.create!(name: "Loja Y", kind: "supplier", tax_id: "11.222.333/0001-81")
    CategoryRule.create!(name: "Por CNPJ", tax_id: "11222333000181", category: @energy, workspace: @workspace)

    tx = @workspace.financial_transactions.new(
      kind: "expense", description: "compra", amount_cents: 5000,
      origin: "manual", status: "pending", counterparty: cp
    )
    s = Aionis::ClassificationEngine.for_transaction(tx).call
    assert_equal @energy.id, s.category_id
  end

  test "faixas de confiança expõem helpers de decisão" do
    s = Aionis::ClassificationEngine::Suggestion.new(confidence: 90)
    assert s.auto_applicable?
    assert_not s.needs_confirmation?

    s = Aionis::ClassificationEngine::Suggestion.new(confidence: 75)
    assert s.needs_confirmation?
    assert_not s.auto_applicable?
  end
end
