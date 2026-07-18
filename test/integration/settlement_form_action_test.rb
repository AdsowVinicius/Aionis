require "test_helper"

class SettlementFormActionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "form@test.com", password: "password123", name: "Form")
    @workspace = Workspace.create!(name: "WS Form", kind: "empresa", owner: @user)
    sign_in @user
  end

  test "new payable form posts to payables route (not financial_transactions)" do
    get new_workspace_payable_path(@workspace)
    assert_response :success
    assert_select "form[action=?]", workspace_payables_path(@workspace)
  end

  test "new receivable form posts to receivables route" do
    get new_workspace_receivable_path(@workspace)
    assert_response :success
    assert_select "form[action=?]", workspace_receivables_path(@workspace)
  end

  test "creating a payable through its form yields an open payable" do
    assert_difference -> { @workspace.financial_transactions.payables.count }, 1 do
      post workspace_payables_path(@workspace), params: {
        financial_transaction: { description: "Aluguel", amount_brl: "1200,00", due_on: Date.current }
      }
    end
    tx = @workspace.financial_transactions.order(:created_at).last
    assert_equal "expense", tx.kind
    assert_equal "open", tx.settlement_status
  end
end
