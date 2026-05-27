# frozen_string_literal: true

class Workspaces::AlertsSummary
  Alert = Data.define(:severity, :kind, :title, :description, :count, :amount_cents)

  SEVERITY_ORDER = { critical: 0, warning: 1, info: 2 }.freeze

  def initialize(workspace)
    @workspace = workspace
  end

  def all
    @all ||= build_alerts.sort_by { |a| SEVERITY_ORDER.fetch(a.severity, 99) }
  end

  def critical
    all.select { |a| a.severity == :critical }
  end

  def warnings
    all.select { |a| a.severity == :warning }
  end

  def info
    all.select { |a| a.severity == :info }
  end

  def critical_count
    critical.sum(&:count)
  end

  def total_count
    all.sum(&:count)
  end

  def any?
    all.any?
  end

  def none?
    !any?
  end

  private

  def build_alerts
    alerts = []
    append_critical(alerts)
    append_warning(alerts)
    append_info(alerts)
    alerts
  end

  # Scopes

  def active_transactions
    @active_transactions ||= @workspace.financial_transactions
      .where.not(status: "cancelled")
      .where(settlement_status: [nil, "open", "settled"])
  end

  def open_payables
    @open_payables ||= @workspace.financial_transactions
      .where(kind: "expense", settlement_status: "open")
      .where.not(status: "cancelled")
  end

  def open_receivables
    @open_receivables ||= @workspace.financial_transactions
      .where(kind: "income", settlement_status: "open")
      .where.not(status: "cancelled")
  end

  # Alert builders

  def append_critical(alerts)
    scope = open_payables.where("due_on < ?", Date.current)
    n = scope.count
    if n > 0
      alerts << alert(:critical, :overdue_payables,
        "Contas a pagar vencidas",
        "#{n} #{n == 1 ? "conta" : "contas"} com vencimento em atraso",
        n, scope.sum(:amount_cents))
    end

    scope = open_receivables.where("due_on < ?", Date.current)
    n = scope.count
    if n > 0
      alerts << alert(:critical, :overdue_receivables,
        "Contas a receber vencidas",
        "#{n} #{n == 1 ? "conta" : "contas"} com recebimento em atraso",
        n, scope.sum(:amount_cents))
    end

    n = @workspace.documents.where(status: "failed").count
    if n > 0
      alerts << alert(:critical, :failed_documents,
        "Documentos com falha",
        "#{n} #{n == 1 ? "documento não pôde" : "documentos não puderam"} ser processado#{n == 1 ? "" : "s"}",
        n, 0)
    end

    realized = active_transactions.where(settlement_status: [nil, "settled"])
    income  = realized.where(kind: "income").sum(:amount_cents)
    expense = realized.where(kind: "expense").sum(:amount_cents)
    balance = income - expense
    if balance < 0
      alerts << alert(:critical, :negative_balance,
        "Saldo geral negativo",
        "O saldo acumulado do workspace está negativo",
        1, balance.abs)
    end
  end

  def append_warning(alerts)
    scope = open_payables.where(due_on: Date.current..3.days.from_now.to_date)
    n = scope.count
    if n > 0
      alerts << alert(:warning, :payables_due_soon,
        "Contas a pagar vencem em breve",
        "#{n} #{n == 1 ? "conta vence" : "contas vencem"} nos próximos 3 dias",
        n, scope.sum(:amount_cents))
    end

    scope = open_payables.where(due_on: 4.days.from_now.to_date..7.days.from_now.to_date)
    n = scope.count
    if n > 0
      alerts << alert(:warning, :payables_due_7days,
        "Contas a pagar em 4 a 7 dias",
        "#{n} #{n == 1 ? "conta vence" : "contas vencem"} em até 7 dias",
        n, scope.sum(:amount_cents))
    end

    scope = open_receivables.where(due_on: Date.current..3.days.from_now.to_date)
    n = scope.count
    if n > 0
      alerts << alert(:warning, :receivables_due_soon,
        "Contas a receber vencem em breve",
        "#{n} #{n == 1 ? "conta vence" : "contas vencem"} nos próximos 3 dias",
        n, scope.sum(:amount_cents))
    end

    n = active_transactions.where(status: "pending").count
    if n > 0
      alerts << alert(:warning, :pending_transactions,
        "Lançamentos pendentes",
        "#{n} #{n == 1 ? "lançamento aguarda" : "lançamentos aguardam"} classificação",
        n, 0)
    end

    n = @workspace.documents.where(status: "review").count
    if n > 0
      alerts << alert(:warning, :review_documents,
        "Documentos em revisão",
        "#{n} #{n == 1 ? "documento aguarda" : "documentos aguardam"} revisão manual",
        n, 0)
    end
  end

  def append_info(alerts)
    n = @workspace.documents.where(status: "pending").count
    if n > 0
      alerts << alert(:info, :pending_documents,
        "Documentos pendentes",
        "#{n} #{n == 1 ? "documento aguarda" : "documentos aguardam"} processamento",
        n, 0)
    end

    scope = open_receivables.where(due_on: 4.days.from_now.to_date..7.days.from_now.to_date)
    n = scope.count
    if n > 0
      alerts << alert(:info, :receivables_due_7days,
        "Contas a receber em 4 a 7 dias",
        "#{n} #{n == 1 ? "conta vence" : "contas vencem"} em até 7 dias",
        n, scope.sum(:amount_cents))
    end

    realized = active_transactions.where(settlement_status: [nil, "settled"])

    n = realized.where(category_id: nil).count
    if n > 0
      alerts << alert(:info, :transactions_no_category,
        "Lançamentos sem categoria",
        "#{n} #{n == 1 ? "lançamento" : "lançamentos"} sem categoria definida",
        n, 0)
    end

    n = realized.where(counterparty_id: nil).count
    if n > 0
      alerts << alert(:info, :transactions_no_counterparty,
        "Lançamentos sem fornecedor/cliente",
        "#{n} #{n == 1 ? "lançamento" : "lançamentos"} sem fornecedor ou cliente",
        n, 0)
    end
  end

  def alert(severity, kind, title, description, count, amount_cents)
    Alert.new(severity: severity, kind: kind, title: title,
              description: description, count: count, amount_cents: amount_cents)
  end
end
