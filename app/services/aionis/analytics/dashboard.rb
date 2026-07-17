# frozen_string_literal: true

module Aionis
  module Analytics
    # Facade do módulo de inteligência financeira: reúne todas as métricas de um
    # workspace num único objeto para a camada de apresentação. O controller
    # apenas chama `Aionis::Analytics::Dashboard.call(workspace)` — nenhuma regra
    # de negócio no controller.
    class Dashboard < Base
      Result = Struct.new(
        :kpis, :health_score, :burn_rate, :essentiality, :cash_flow, :forecast,
        :abc_curve, :top_categories, :top_counterparties, :top_cost_centers,
        :monthly_evolution, :recent_transactions, :insights,
        keyword_init: true
      )

      def call
        rankings = Rankings.new(workspace, on: on).call

        Result.new(
          kpis:              Kpis.new(workspace, on: on).call,
          health_score:      HealthScore.new(workspace, on: on).call,
          burn_rate:         BurnRate.new(workspace, on: on).call,
          essentiality:      EssentialityBreakdown.new(workspace, on: on).call,
          cash_flow:         CashFlow.new(workspace, on: on).call,
          forecast:          Forecast.new(workspace, on: on).call,
          abc_curve:         AbcCurve.new(workspace, on: on).call,
          top_categories:    rankings[:categories],
          top_counterparties: rankings[:counterparties],
          top_cost_centers:  rankings[:cost_centers],
          monthly_evolution: MonthlyEvolution.new(workspace, on: on).call,
          recent_transactions: recent_transactions,
          insights:          InsightGenerator.new(workspace, on: on).build
        )
      end

      private

      def recent_transactions
        realized
          .includes(:category, :counterparty, :document)
          .order(Arel.sql("#{DATE_SQL} DESC, financial_transactions.created_at DESC"))
          .limit(8)
      end
    end
  end
end
