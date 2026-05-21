module Workspaces
  class DashboardController < Workspaces::BaseController
    def show
      @workspace = current_workspace
      @income_cents  = @workspace.financial_transactions.where(kind: "income").sum(:amount_cents)
      @expense_cents = @workspace.financial_transactions.where(kind: "expense").sum(:amount_cents)
      @balance_cents = @income_cents - @expense_cents
      @pending_docs  = @workspace.documents.where(status: "pending").count
      @recent_transactions = @workspace.financial_transactions
                                       .includes(:category, :counterparty)
                                       .order(created_at: :desc)
                                       .limit(5)
    end
  end
end
