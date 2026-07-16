require "test_helper"

class Aionis::OpenFinance::ReconcilerTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "R", email: "recon_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @consent = @workspace.consents.create!(provider: "pluggy", external_id: "item1", status: "active")
    @account = @consent.bank_accounts.create!(workspace: @workspace, external_id: "acc1", kind: "checking")
  end

  def ft(amount:, on:, description:, kind: "expense")
    @workspace.financial_transactions.create!(kind: kind, description: description,
      amount_cents: amount, origin: "manual", status: "pending", transacted_on: on)
  end

  def bt(amount:, on:, description:, direction: "debit", id: "t#{SecureRandom.hex(3)}")
    @account.bank_transactions.create!(workspace: @workspace, external_id: id,
      amount_cents: amount, direction: direction, posted_on: on, description: description)
  end

  test "valor idêntico, mesma data e descrição semelhante confirma automaticamente" do
    lancamento = ft(amount: 5_000, on: Date.new(2026, 7, 10), description: "Mercado Silva")
    bank = bt(amount: 5_000, on: Date.new(2026, 7, 10), description: "MERCADO SILVA COMPRA")

    match = Aionis::OpenFinance::Reconciler.call(bank)

    assert_equal "confirmed", match.status
    assert_operator match.score, :>=, 85
    assert bank.reload.matched?
    assert_equal lancamento.id, bank.financial_transaction_id
  end

  test "data distante sem descrição gera apenas sugestão" do
    ft(amount: 8_000, on: Date.new(2026, 7, 10), description: "Aluguel")
    bank = bt(amount: 8_000, on: Date.new(2026, 7, 13), description: "PIX ENVIADO")

    match = Aionis::OpenFinance::Reconciler.call(bank)

    assert_equal "suggested", match.status
    assert bank.reload.pending?
  end

  test "sem candidato de mesmo valor não concilia" do
    ft(amount: 9_999, on: Date.current, description: "Outro")
    bank = bt(amount: 1_234, on: Date.current, description: "Compra")

    assert_nil Aionis::OpenFinance::Reconciler.call(bank)
  end

  test "não reconcilia transação já conciliada" do
    ft(amount: 5_000, on: Date.current, description: "X")
    bank = bt(amount: 5_000, on: Date.current, description: "X")
    bank.update!(reconciliation_status: "matched")

    assert_nil Aionis::OpenFinance::Reconciler.call(bank)
  end

  test "credito casa com receita" do
    receita = ft(amount: 20_000, on: Date.new(2026, 7, 5), description: "Consultoria", kind: "income")
    bank = bt(amount: 20_000, on: Date.new(2026, 7, 5), description: "TED CONSULTORIA", direction: "credit")

    match = Aionis::OpenFinance::Reconciler.call(bank)
    assert_equal "confirmed", match.status
    assert_equal receita.id, bank.reload.financial_transaction_id
  end
end
