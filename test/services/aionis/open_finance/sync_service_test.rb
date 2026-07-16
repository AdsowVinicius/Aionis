require "test_helper"

class Aionis::OpenFinance::SyncServiceTest < ActiveSupport::TestCase
  class FakeOF
    def fetch_accounts(consent_id:)
      Aionis::Integrations::Result.ok(provider: "pluggy", data: { "accounts" => [
        { "external_id" => "acc1", "name" => "Conta", "institution" => "Banco X",
          "branch" => "0001", "number" => "123", "kind" => "checking",
          "currency" => "BRL", "balance_cents" => 100_00 }
      ] })
    end

    def fetch_transactions(account_id:, from:, to:)
      Aionis::Integrations::Result.ok(provider: "pluggy", data: { "transactions" => [
        { "external_id" => "t1", "amount_cents" => 5_000, "direction" => "debit",
          "date" => "2026-07-10", "description" => "MERCADO SILVA", "raw" => {} }
      ] })
    end
  end

  setup do
    @user = User.create!(name: "S", email: "sync_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @consent = @workspace.consents.create!(provider: "pluggy", external_id: "item1", status: "active")
    Aionis::Integrations.override(:open_finance, FakeOF.new)
  end

  teardown { Aionis::Integrations.reset! }

  test "sincroniza contas e transações" do
    result = Aionis::OpenFinance::SyncService.call(@consent)

    assert_equal({ accounts: 1, transactions: 1 }, result)
    assert_equal 1, @consent.bank_accounts.count
    account = @consent.bank_accounts.first
    assert_equal "Banco X", account.institution
    assert_equal 1, account.bank_transactions.count
    assert_not_nil @consent.reload.last_synced_at
  end

  test "é idempotente (não duplica transações)" do
    Aionis::OpenFinance::SyncService.call(@consent)
    result = Aionis::OpenFinance::SyncService.call(@consent)
    assert_equal 0, result[:transactions]
    assert_equal 1, BankTransaction.where(workspace_id: @workspace.id).count
  end

  test "concilia transação com lançamento correspondente" do
    lancamento = @workspace.financial_transactions.create!(
      kind: "expense", description: "Mercado Silva", amount_cents: 5_000,
      origin: "manual", status: "pending", transacted_on: Date.new(2026, 7, 10)
    )
    Aionis::OpenFinance::SyncService.call(@consent)

    bt = BankTransaction.find_by(external_id: "t1")
    assert bt.matched?
    assert_equal lancamento.id, bt.financial_transaction_id
  end

  test "consentimento não ativo não sincroniza" do
    @consent.update!(status: "pending")
    result = Aionis::OpenFinance::SyncService.call(@consent)
    assert_equal({ accounts: 0, transactions: 0 }, result)
  end
end
