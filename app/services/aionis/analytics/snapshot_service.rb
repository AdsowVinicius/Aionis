# frozen_string_literal: true

module Aionis
  module Analytics
    # Persiste um KpiSnapshot do mês (idempotente por período) e, opcionalmente,
    # gera os insights. Base para acompanhamento histórico e evolução mensal.
    class SnapshotService < Base
      def call(with_insights: true)
        dash  = Dashboard.new(workspace, on: on).call
        label = on.strftime("%Y-%m")
        from, to = month_range(on)

        snapshot = workspace.kpi_snapshots.find_or_initialize_by(period_label: label)
        snapshot.assign_attributes(
          period_start:   from,
          period_end:     to,
          captured_on:    Date.current,
          income_cents:   dash.kpis.income_cents,
          expense_cents:  dash.kpis.expense_cents,
          balance_cents:  dash.kpis.balance_cents,
          health_score:   dash.health_score.score,
          burn_rate_cents: dash.burn_rate.monthly_burn_cents,
          data: {
            "savings_rate"      => dash.kpis.savings_rate,
            "health_band"       => dash.health_score.band,
            "essential_ratio"   => dash.essentiality.essential_ratio,
            "superfluous_ratio" => dash.essentiality.superfluous_ratio,
            "runway_months"     => dash.burn_rate.runway_months,
            "general_balance_cents" => dash.kpis.general_balance_cents
          }
        )
        snapshot.save!

        InsightGenerator.new(workspace, on: on).generate! if with_insights
        snapshot
      end
    end
  end
end
