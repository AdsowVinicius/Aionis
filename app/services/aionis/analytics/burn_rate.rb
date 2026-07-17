# frozen_string_literal: true

module Aionis
  module Analytics
    # Burn rate: consumo médio mensal de caixa (saídas líquidas) nos últimos N
    # meses completos e o "runway" (meses de fôlego) com o saldo atual.
    class BurnRate < Base
      def initialize(workspace, on: Date.current, months: 3)
        super(workspace, on: on)
        @months = months
      end

      Result = Struct.new(:monthly_burn_cents, :runway_months, :trend, :positive_cashflow, keyword_init: true)

      def call
        # meses completos anteriores ao mês corrente
        nets = MonthlyEvolution.new(workspace, on: on.prev_month, months: @months).call.map { |m| m[:balance_cents] }
        burns = nets.map { |n| n.negative? ? -n : 0 }
        avg_burn = burns.empty? ? 0 : (burns.sum / burns.size)

        cash = Kpis.new(workspace, on: on).call.general_balance_cents
        runway = avg_burn.positive? && cash.positive? ? (cash.to_f / avg_burn).round(1) : nil

        Result.new(
          monthly_burn_cents: avg_burn,
          runway_months:      runway,
          trend:              trend(burns),
          positive_cashflow:  avg_burn.zero?
        )
      end

      private

      def trend(burns)
        return "stable" if burns.size < 2
        first_half = burns.first(burns.size / 2)
        last_half  = burns.last(burns.size / 2)
        a = first_half.sum / [first_half.size, 1].max
        b = last_half.sum / [last_half.size, 1].max
        return "up"   if b > a * 1.1
        return "down" if b < a * 0.9
        "stable"
      end
    end
  end
end
