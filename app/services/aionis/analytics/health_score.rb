# frozen_string_literal: true

module Aionis
  module Analytics
    # Score de saúde financeira (0..100) a partir de saldo, poupança,
    # gastos supérfluos e contas vencidas. Retorna score, faixa e fatores.
    class HealthScore < Base
      Result = Struct.new(:score, :band, :factors, keyword_init: true)

      def call
        kpis = Kpis.new(workspace, on: on).call
        ess  = EssentialityBreakdown.new(workspace, on: on).call

        factors = []
        score = 50

        factors << factor("Saldo geral", apply(score_delta_balance(kpis)) { |d| score += d })
        factors << factor("Taxa de poupança do mês", apply(score_delta_savings(kpis)) { |d| score += d })
        factors << factor("Gastos supérfluos", apply(score_delta_superfluous(ess)) { |d| score += d })
        factors << factor("Contas vencidas", apply(score_delta_overdue(kpis)) { |d| score += d })

        score = score.round.clamp(0, 100)
        Result.new(score: score, band: band(score), factors: factors)
      end

      private

      def apply(delta)
        yield delta
        delta
      end

      def factor(label, delta) = { label: label, impact: delta.round }

      def score_delta_balance(kpis)
        kpis.general_balance_cents.positive? ? 15 : -20
      end

      def score_delta_savings(kpis)
        rate = kpis.savings_rate
        return [rate / 100.0 * 15, 15].min if rate.positive?
        [-10, rate / 100.0 * 10].max # taxa negativa penaliza (limitado a -10)
      end

      def score_delta_superfluous(ess)
        -(ess.superfluous_ratio / 100.0 * 15)
      end

      def score_delta_overdue(kpis)
        -[kpis.overdue_payables_count * 5, 15].min
      end

      def band(score)
        return "healthy"   if score >= 75
        return "attention" if score >= 50
        "critical"
      end
    end
  end
end
