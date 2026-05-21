require "test_helper"

class FinancialTransactionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Teste",
      email: "ft_test@aionis.test",
      password: "senha1234"
    )
    @workspace = Workspace.create!(name: "WS FT", kind: "empresa", owner: @user)
  end

  def minimal_attrs(overrides = {})
    {
      workspace:    @workspace,
      kind:         "expense",
      description:  "Compra de material na loja do bairro",
      amount_cents: 12000,
      origin:       "manual",
      status:       "pending"
    }.merge(overrides)
  end

  # Regra central: lançamento manual sem fornecedor, documento ou categoria é válido
  test "salva com apenas campos obrigatórios" do
    t = FinancialTransaction.new(minimal_attrs)
    assert t.valid?, t.errors.full_messages.inspect
    assert t.save
  end

  test "salva sem document_id" do
    t = FinancialTransaction.new(minimal_attrs(document_id: nil))
    assert t.valid?, t.errors.full_messages.inspect
  end

  test "salva sem counterparty_id" do
    t = FinancialTransaction.new(minimal_attrs(counterparty_id: nil))
    assert t.valid?, t.errors.full_messages.inspect
  end

  test "salva sem category_id" do
    t = FinancialTransaction.new(minimal_attrs(category_id: nil))
    assert t.valid?, t.errors.full_messages.inspect
  end

  test "salva sem nenhum dos três opcionais" do
    t = FinancialTransaction.new(minimal_attrs(
      document_id:    nil,
      counterparty_id: nil,
      category_id:    nil
    ))
    assert t.valid?, t.errors.full_messages.inspect
    assert t.save
  end

  test "requer description" do
    t = FinancialTransaction.new(minimal_attrs(description: nil))
    assert_not t.valid?
    assert t.errors[:description].any?
  end

  test "requer amount_cents maior que zero" do
    t = FinancialTransaction.new(minimal_attrs(amount_cents: 0))
    assert_not t.valid?
    assert t.errors[:amount_cents].any?
  end

  test "amount_brl converte centavos para reais" do
    t = FinancialTransaction.new(amount_cents: 12000)
    assert_equal 120.0, t.amount_brl
  end
end
