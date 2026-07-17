# frozen_string_literal: true

module Aionis
  module Analytics
    # Gera insights de saúde financeira a partir das métricas. `build` retorna os
    # insights calculados (para exibir no dashboard, sem persistir); `generate!`
    # persiste como registros Insight (idempotente por kind + dia).
    class InsightGenerator < Base
      def build
        kpis = Kpis.new(workspace, on: on).call
        ess  = EssentialityBreakdown.new(workspace, on: on).call
        burn = BurnRate.new(workspace, on: on).call
        hs   = HealthScore.new(workspace, on: on).call

        insights = []

        if kpis.balance_cents.negative?
          insights << item("negative_month_balance", "critical", "Saldo do mês negativo",
                           "Suas despesas superaram as receitas neste mês.",
                           balance_cents: kpis.balance_cents)
        end

        if ess.superfluous_ratio >= 25
          insights << item("high_superfluous", "warning", "Gastos supérfluos altos",
                           "#{ess.superfluous_ratio}% das despesas são supérfluas ou não essenciais.",
                           ratio: ess.superfluous_ratio)
        end

        if kpis.overdue_payables_count.positive?
          insights << item("overdue_payables", "warning", "Contas vencidas",
                           "Você tem #{kpis.overdue_payables_count} conta(s) a pagar vencida(s).",
                           count: kpis.overdue_payables_count)
        end

        if burn.runway_months && burn.runway_months < 3
          insights << item("short_runway", "critical", "Fôlego de caixa curto",
                           "No ritmo atual de gastos, seu caixa dura cerca de #{burn.runway_months} meses.",
                           runway_months: burn.runway_months)
        end

        if kpis.savings_rate >= 20
          insights << item("healthy_savings", "info", "Boa taxa de poupança",
                           "Você guardou #{kpis.savings_rate}% da receita neste mês.",
                           savings_rate: kpis.savings_rate)
        end

        if hs.band == "critical"
          insights << item("low_health", "critical", "Saúde financeira crítica",
                           "Seu score de saúde financeira está em #{hs.score}/100.",
                           score: hs.score)
        end

        insights
      end

      # Persiste os insights atuais (um por kind por dia).
      def generate!
        build.map do |data|
          insight = workspace.insights.find_or_initialize_by(kind: data[:kind], generated_on: on)
          insight.assign_attributes(
            severity: data[:severity], title: data[:title],
            message: data[:message], data: data[:data], status: "active"
          )
          insight.save!
          insight
        end
      end

      private

      def item(kind, severity, title, message, **data)
        { kind: kind, severity: severity, title: title, message: message, data: data }
      end
    end
  end
end
