module Workspaces
  class DashboardController < Workspaces::BaseController
    def show
      @workspace = current_workspace

      # Lançamentos do mês atual usando transacted_on; fallback para created_at::date quando nulo.
      start_of_month = Date.current.beginning_of_month
      end_of_month   = Date.current.end_of_month

      monthly = @workspace.financial_transactions.where(
        "COALESCE(transacted_on, created_at::date) BETWEEN ? AND ?",
        start_of_month, end_of_month
      )

      @income_cents  = monthly.where(kind: "income").sum(:amount_cents)
      @expense_cents = monthly.where(kind: "expense").sum(:amount_cents)
      @balance_cents = @income_cents - @expense_cents

      @pending_docs        = @workspace.documents.where(status: "pending").count
      @transactions_count  = @workspace.financial_transactions.count

      @recent_transactions = @workspace.financial_transactions
                                       .includes(:category, :counterparty)
                                       .order(created_at: :desc)
                                       .limit(5)
    end
  end
end
