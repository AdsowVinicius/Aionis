# frozen_string_literal: true

module Aionis
  module Analytics
    # KPIs principais do mês e gerais, mais contadores operacionais.
    class Kpis < Base
      Result = Struct.new(
        :income_cents, :expense_cents, :balance_cents,
        :general_income_cents, :general_expense_cents, :general_balance_cents,
        :savings_rate, :pending_transactions_count, :pending_docs, :review_docs,
        :counterparties_count, :overdue_payables_count, :overdue_receivables_count,
        :upcoming_payables_cents, :upcoming_receivables_cents, :status_summary,
        keyword_init: true
      )

      def call
        from, to = month_range(on)
        monthly  = in_range(realized, from, to)

        income  = sum_cents(monthly.where(kind: "income"))
        expense = sum_cents(monthly.where(kind: "expense"))
        gen_income  = sum_cents(incomes)
        gen_expense = sum_cents(expenses)

        Result.new(
          income_cents:  income,
          expense_cents: expense,
          balance_cents: income - expense,
          general_income_cents:  gen_income,
          general_expense_cents: gen_expense,
          general_balance_cents: gen_income - gen_expense,
          savings_rate: pct(income - expense, income),
          pending_transactions_count: workspace.financial_transactions.where(status: "pending").count,
          pending_docs: workspace.documents.where(status: "pending").count,
          review_docs:  workspace.documents.where(status: "review").count,
          counterparties_count: workspace.counterparties.count,
          overdue_payables_count:    workspace.financial_transactions.payables.overdue.count,
          overdue_receivables_count: workspace.financial_transactions.receivables.overdue.count,
          upcoming_payables_cents:    workspace.financial_transactions.payables.upcoming.sum(:amount_cents).to_i,
          upcoming_receivables_cents: workspace.financial_transactions.receivables.upcoming.sum(:amount_cents).to_i,
          status_summary: workspace.financial_transactions.group(:status).count
        )
      end
    end
  end
end
