require "test_helper"

class Aionis::RuleLearnerTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Learner Test",
      email: "learner_#{SecureRandom.hex(4)}@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS Learner", kind: "empresa", owner: @user)

    @transport = Category.create!(name: "Transporte #{SecureRandom.hex(2)}", kind: "expense",
                                  cost_type: "variable", essentiality: "operational_important")
    @food = Category.create!(name: "Alimentação #{SecureRandom.hex(2)}", kind: "expense",
                             cost_type: "variable", essentiality: "non_essential")
  end

  # Cria um lançamento persistido como se o usuário tivesse escolhido a
  # categoria manualmente (é o gatilho de aprendizado).
  def manual_tx(description:, category:, counterparty: nil, tax_id_snapshot: nil, kind: "expense")
    @workspace.financial_transactions.create!(
      kind: kind, description: description, amount_cents: 5000, origin: "manual",
      status: "confirmed", category: category, counterparty: counterparty,
      counterparty_tax_id_snapshot: tax_id_snapshot,
      classification_source: "manual", classification_confidence: 100
    )
  end

  test "cria regra por fornecedor a partir de correção manual" do
    cp = @workspace.counterparties.create!(name: "Uber do Brasil", kind: "supplier")
    tx = manual_tx(description: "corrida app", category: @transport, counterparty: cp)

    rule = nil
    assert_difference -> { CategoryRule.learned.count }, 1 do
      rule = Aionis::RuleLearner.for(tx).call
    end

    assert_equal "learned", rule.origin
    assert_equal @workspace.id, rule.workspace_id
    assert_equal cp.id, rule.counterparty_id
    assert_equal @transport.id, rule.category_id
    assert_equal "expense", rule.kind
    assert_operator rule.confidence, :>=, 80
    assert rule.active?
  end

  test "cria regra por CPF/CNPJ quando não há fornecedor vinculado" do
    tx = manual_tx(description: "compra avulsa", category: @food, tax_id_snapshot: "11.222.333/0001-81")

    rule = Aionis::RuleLearner.for(tx).call

    assert_equal "11222333000181", rule.tax_id
    assert_nil rule.counterparty_id
    assert_equal @food.id, rule.category_id
  end

  test "cria regra por palavra-chave quando não há fornecedor nem CPF/CNPJ" do
    tx = manual_tx(description: "Almoço no restaurante japonês", category: @food)

    rule = Aionis::RuleLearner.for(tx).call

    assert_equal @food.id, rule.category_id
    assert_nil rule.counterparty_id
    assert_nil rule.tax_id
    # stopwords ("no") descartadas; sobram tokens significativos ordenados
    assert_includes rule.keyword_list, "restaurante"
    assert_includes rule.keyword_list, "japones"
    refute_includes rule.keyword_list, "no"
  end

  test "regra aprendida faz o motor classificar o próximo lançamento igual" do
    cp = @workspace.counterparties.create!(name: "Posto Ipiranga", kind: "supplier")
    tx = manual_tx(description: "abastecimento", category: @transport, counterparty: cp)
    Aionis::RuleLearner.for(tx).call

    suggestion = Aionis::ClassificationEngine.new(
      workspace: @workspace, description: "novo abastecimento",
      kind: "expense", counterparty_id: cp.id
    ).call

    assert_equal @transport.id, suggestion.category_id
  end

  test "reforça regra existente ao invés de duplicar" do
    cp = @workspace.counterparties.create!(name: "Padaria Central", kind: "supplier")
    tx1 = manual_tx(description: "pão", category: @food, counterparty: cp)
    first = Aionis::RuleLearner.for(tx1).call
    base_conf = first.confidence

    tx2 = manual_tx(description: "leite", category: @food, counterparty: cp)
    reinforced = nil
    assert_no_difference -> { CategoryRule.learned.count } do
      reinforced = Aionis::RuleLearner.for(tx2).call
    end

    assert_equal first.id, reinforced.id
    assert_equal 1, reinforced.times_reinforced
    assert_operator reinforced.confidence, :>, base_conf
    assert_operator reinforced.priority, :>, first.priority - 1
  end

  test "quando usuário troca de categoria, a regra aponta para a nova" do
    cp = @workspace.counterparties.create!(name: "Mercadinho", kind: "supplier")
    Aionis::RuleLearner.for(manual_tx(description: "item", category: @food, counterparty: cp)).call
    reinforced = Aionis::RuleLearner.for(manual_tx(description: "item", category: @transport, counterparty: cp)).call

    assert_equal @transport.id, reinforced.category_id
    assert_equal 1, CategoryRule.learned.where(counterparty_id: cp.id).count
  end

  test "não aprende quando a classificação não foi manual" do
    cp = @workspace.counterparties.create!(name: "Auto", kind: "supplier")
    tx = @workspace.financial_transactions.create!(
      kind: "expense", description: "auto", amount_cents: 100, origin: "manual",
      status: "confirmed", category: @food, counterparty: cp,
      classification_source: "rule"
    )

    assert_no_difference -> { CategoryRule.learned.count } do
      assert_nil Aionis::RuleLearner.for(tx).call
    end
  end

  test "não aprende quando o motor já sugeria a mesma categoria" do
    # Regra global que já classifica corretamente por palavra-chave
    CategoryRule.create!(name: "Global comida", keywords: "sushi", kind: "expense",
                         category: @food, origin: "seed")
    tx = manual_tx(description: "sushi delivery", category: @food)

    assert_no_difference -> { CategoryRule.learned.count } do
      assert_nil Aionis::RuleLearner.for(tx).call
    end
  end

  test "não aprende sem condição utilizável (só stopwords e números)" do
    tx = manual_tx(description: "compra 123 loja", category: @food)

    assert_no_difference -> { CategoryRule.learned.count } do
      assert_nil Aionis::RuleLearner.for(tx).call
    end
  end
end
