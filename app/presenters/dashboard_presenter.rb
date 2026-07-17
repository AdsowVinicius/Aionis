# frozen_string_literal: true

# Presenter da página de Dashboard. Compõe (sem duplicar cálculo) o módulo de
# inteligência financeira (Aionis::Analytics::Dashboard) com os dados de página
# não-analíticos (documentos e mensagens recentes, contas a vencer, alertas).
# O controller apenas instancia este presenter; a view só lê seus métodos.
class DashboardPresenter
  def initialize(workspace)
    @workspace = workspace
  end

  # --- Inteligência financeira (Aionis::Analytics::Dashboard) ---

  def analytics = @analytics ||= Aionis::Analytics::Dashboard.call(@workspace)

  def kpis               = analytics.kpis
  def health             = analytics.health_score
  def burn_rate          = analytics.burn_rate
  def cash_flow          = analytics.cash_flow
  def forecast           = analytics.forecast
  def monthly_evolution  = analytics.monthly_evolution
  def essentiality       = analytics.essentiality
  def abc_curve          = analytics.abc_curve
  def top_categories     = analytics.top_categories
  def top_counterparties = analytics.top_counterparties
  def top_cost_centers   = analytics.top_cost_centers
  def insights           = analytics.insights
  def recent_transactions = analytics.recent_transactions

  # --- Dados de página (leitura, sem regra de negócio) ---

  def alerts = @alerts ||= Workspaces::AlertsSummary.new(@workspace)

  def recent_documents
    @recent_documents ||= @workspace.documents
                                    .with_attached_file
                                    .order(created_at: :desc)
                                    .limit(5)
  end

  def recent_messages
    @recent_messages ||= @workspace.incoming_messages
                                   .order(Arel.sql("COALESCE(received_at, created_at) DESC"))
                                   .limit(5)
  end

  def upcoming_payables
    @upcoming_payables ||= @workspace.financial_transactions.payables.upcoming
                                     .includes(:category, :counterparty).order(:due_on).limit(5)
  end

  # Estado inicial: nenhuma atividade ainda (para o "empty state"). Considera
  # lançamentos E documentos — quem tem só contas a vencer já vê o dashboard.
  def empty?
    @workspace.financial_transactions.none? && @workspace.documents.none?
  end
end
