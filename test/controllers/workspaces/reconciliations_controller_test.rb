require "test_helper"

class Workspaces::ReconciliationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(name: "R", email: "rec_#{SecureRandom.hex(4)}@t.test", password: "senha1234")
    @workspace = Workspace.create!(name: "WS", kind: "empresa", owner: @user)
    @consent = @workspace.consents.create!(provider: "pluggy", external_id: "item1", status: "active")
    @account = @consent.bank_accounts.create!(workspace: @workspace, external_id: "acc1", kind: "checking")
    sign_in @user
  end

  def match(status: "suggested")
    ft = @workspace.financial_transactions.create!(kind: "expense", description: "Mercado", amount_cents: 5_000,
                                                   origin: "manual", status: "pending", transacted_on: Date.current)
    bt = @account.bank_transactions.create!(workspace: @workspace, external_id: "t#{SecureRandom.hex(3)}",
                                            amount_cents: 5_000, direction: "debit", posted_on: Date.current, description: "MERCADO")
    @workspace.reconciliation_matches.create!(bank_transaction: bt, financial_transaction: ft,
                                              score: 90, status: status, reasons: ["valor idêntico"])
  end

  test "index lista sugestões" do
    m = match
    get workspace_reconciliations_path(@workspace)
    assert_response :success
    assert_match "MERCADO", @response.body
    assert_match "Confirmar", @response.body
  end

  test "confirmar concilia a transação bancária" do
    m = match
    patch confirm_workspace_reconciliation_path(@workspace, m)
    assert_redirected_to workspace_reconciliations_path(@workspace)

    m.reload
    assert m.confirmed?
    assert_equal "user", m.matched_by
    assert m.bank_transaction.reload.matched?
    assert_equal m.financial_transaction_id, m.bank_transaction.financial_transaction_id
  end

  test "rejeitar marca a sugestão como rejeitada" do
    m = match
    patch reject_workspace_reconciliation_path(@workspace, m)
    assert_redirected_to workspace_reconciliations_path(@workspace)

    m.reload
    assert m.rejected?
    assert m.bank_transaction.reload.pending?
  end

  test "filtra por status" do
    match(status: "confirmed")
    get workspace_reconciliations_path(@workspace, status: "suggested")
    assert_response :success
    assert_match "Nada por aqui", @response.body
  end

  test "não acessa match de outro workspace" do
    other = Workspace.create!(name: "Outro", kind: "empresa", owner: @user)
    consent = other.consents.create!(provider: "pluggy", external_id: "i2", status: "active")
    account = consent.bank_accounts.create!(workspace: other, external_id: "a2", kind: "checking")
    ft = other.financial_transactions.create!(kind: "expense", description: "x", amount_cents: 100, origin: "manual", status: "pending")
    bt = account.bank_transactions.create!(workspace: other, external_id: "z1", amount_cents: 100, direction: "debit")
    m = other.reconciliation_matches.create!(bank_transaction: bt, financial_transaction: ft, score: 90)

    patch confirm_workspace_reconciliation_path(@workspace, m)
    assert_response :not_found
  end
end
