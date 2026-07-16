require "test_helper"

class OpenFinanceModelsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "OF", email: "of_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS OF", kind: "empresa", owner: @user)
    @consent = @workspace.consents.create!(provider: "pluggy", external_id: "item1", status: "active")
    @account = @consent.bank_accounts.create!(workspace: @workspace, external_id: "acc1", kind: "checking")
  end

  test "BankAccount deduplica por consent + external_id" do
    dup = @consent.bank_accounts.build(workspace: @workspace, external_id: "acc1")
    refute dup.valid?
  end

  test "BankTransaction exige valor positivo e direção válida" do
    bt = @account.bank_transactions.build(workspace: @workspace, external_id: "t1",
                                          amount_cents: 0, direction: "debit")
    refute bt.valid?
    bt.amount_cents = 100
    bt.direction = "xpto"
    refute bt.valid?
  end

  test "BankTransaction#financial_kind mapeia direção" do
    debit  = @account.bank_transactions.new(direction: "debit")
    credit = @account.bank_transactions.new(direction: "credit")
    assert_equal "expense", debit.financial_kind
    assert_equal "income",  credit.financial_kind
  end

  test "ReconciliationMatch valida score 0..100" do
    ft = @workspace.financial_transactions.create!(kind: "expense", description: "x",
                                                   amount_cents: 100, origin: "manual", status: "pending")
    bt = @account.bank_transactions.create!(workspace: @workspace, external_id: "t2",
                                            amount_cents: 100, direction: "debit")
    m = @workspace.reconciliation_matches.build(bank_transaction: bt, financial_transaction: ft, score: 150)
    refute m.valid?
  end

  test "workspace destrói consentimentos, contas e transações em cascata" do
    @account.bank_transactions.create!(workspace: @workspace, external_id: "t3",
                                       amount_cents: 100, direction: "debit")
    assert_difference -> { Consent.count } => -1,
                      -> { BankAccount.count } => -1,
                      -> { BankTransaction.count } => -1 do
      @workspace.destroy
    end
  end
end
