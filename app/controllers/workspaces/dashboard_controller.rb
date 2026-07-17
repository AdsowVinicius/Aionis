module Workspaces
  class DashboardController < Workspaces::BaseController
    # Sem regra de negócio aqui: toda a inteligência financeira vem de
    # Aionis::Analytics::Dashboard. O controller apenas expõe os dados à view.
    def show
      @workspace      = current_workspace
      @alerts_summary = Workspaces::AlertsSummary.new(@workspace)
      @analytics      = Aionis::Analytics::Dashboard.call(@workspace)

      assign_legacy_ivars(@analytics)
    end

    private

    # Compatibilidade com a view atual (atribuições puras — nenhuma lógica).
    def assign_legacy_ivars(a)
      k = a.kpis
      @income_cents          = k.income_cents
      @expense_cents         = k.expense_cents
      @balance_cents         = k.balance_cents
      @general_income_cents  = k.general_income_cents
      @general_expense_cents = k.general_expense_cents
      @general_balance_cents = k.general_balance_cents
      @pending_transactions_count = k.pending_transactions_count
      @pending_docs               = k.pending_docs
      @review_docs                = k.review_docs
      @counterparties_count       = k.counterparties_count
      @overdue_payables_count     = k.overdue_payables_count
      @overdue_receivables_count  = k.overdue_receivables_count
      @upcoming_payables_cents    = k.upcoming_payables_cents
      @upcoming_receivables_cents = k.upcoming_receivables_cents
      @status_summary             = k.status_summary
      @top_categories       = a.top_categories
      @top_counterparties   = a.top_counterparties
      @recent_transactions  = a.recent_transactions
    end
  end
end
