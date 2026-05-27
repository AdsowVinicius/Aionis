module Workspaces
  class DashboardController < Workspaces::BaseController
    def show
      @workspace      = current_workspace
      @alerts_summary = Workspaces::AlertsSummary.new(@workspace)

      period_start = Date.current.beginning_of_month
      period_end   = Date.current.end_of_month

      # Base scopes — excluem cancelled E contas abertas (settlement_status: open)
      # Contas abertas não entraram no caixa ainda; só entram quando liquidadas (settled) ou sem settlement_status
      all_active = @workspace.financial_transactions
                             .where.not(status: "cancelled")
                             .where(settlement_status: [nil, "settled"])

      monthly = all_active.where(
        "COALESCE(financial_transactions.transacted_on, financial_transactions.created_at::date) BETWEEN ? AND ?",
        period_start, period_end
      )

      # ── Cards principais ────────────────────────────────────────────────────
      @income_cents  = monthly.where(kind: "income").sum(:amount_cents)
      @expense_cents = monthly.where(kind: "expense").sum(:amount_cents)
      @balance_cents = @income_cents - @expense_cents

      @general_income_cents  = all_active.where(kind: "income").sum(:amount_cents)
      @general_expense_cents = all_active.where(kind: "expense").sum(:amount_cents)
      @general_balance_cents = @general_income_cents - @general_expense_cents

      # ── Cards operacionais ──────────────────────────────────────────────────
      @pending_transactions_count = @workspace.financial_transactions.where(status: "pending").count
      @pending_docs               = @workspace.documents.where(status: "pending").count
      @review_docs                = @workspace.documents.where(status: "review").count
      @counterparties_count       = @workspace.counterparties.count

      # ── Alertas de contas a pagar/receber ──────────────────────────────────
      @overdue_payables_count    = @workspace.financial_transactions.payables.overdue.count
      @overdue_receivables_count = @workspace.financial_transactions.receivables.overdue.count
      @upcoming_payables_cents   = @workspace.financial_transactions.payables.upcoming.sum(:amount_cents)
      @upcoming_receivables_cents = @workspace.financial_transactions.receivables.upcoming.sum(:amount_cents)

      # ── Resumo por status ───────────────────────────────────────────────────
      @status_summary = @workspace.financial_transactions.group(:status).count

      # ── Top 5 categorias de despesa do mês ─────────────────────────────────
      @top_categories = monthly
        .where(kind: "expense")
        .where.not(category_id: nil)
        .joins(:category)
        .group("categories.id", "categories.name")
        .order("SUM(financial_transactions.amount_cents) DESC")
        .limit(5)
        .pluck("categories.name",
               "SUM(financial_transactions.amount_cents)",
               "COUNT(financial_transactions.id)")
        .map { |name, total, count| { name: name, total_cents: total.to_i, count: count.to_i } }

      # ── Top 5 fornecedores/clientes do mês ─────────────────────────────────
      @top_counterparties = monthly
        .where.not(counterparty_id: nil)
        .joins(:counterparty)
        .group("counterparties.id", "counterparties.name")
        .order("SUM(financial_transactions.amount_cents) DESC")
        .limit(5)
        .pluck("counterparties.name",
               "SUM(financial_transactions.amount_cents)",
               "COUNT(financial_transactions.id)")
        .map { |name, total, count| { name: name, total_cents: total.to_i, count: count.to_i } }

      # ── Últimos lançamentos realizados (sem N+1) ────────────────────────────
      @recent_transactions = @workspace.financial_transactions
                                       .where(settlement_status: [nil, "settled"])
                                       .where.not(status: "cancelled")
                                       .includes(:category, :counterparty, :document)
                                       .order(
                                         Arel.sql("COALESCE(financial_transactions.transacted_on, financial_transactions.created_at::date) DESC, financial_transactions.created_at DESC")
                                       )
                                       .limit(8)
    end
  end
end
