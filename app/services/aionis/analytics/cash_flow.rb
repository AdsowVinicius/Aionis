# frozen_string_literal: true

module Aionis
  module Analytics
    # Fluxo de caixa mensal (entradas, saídas e líquido) e acumulado.
    class CashFlow < Base
      def initialize(workspace, on: Date.current, months: 6)
        super(workspace, on: on)
        @months = months
      end

      def call
        running = 0
        MonthlyEvolution.new(workspace, on: on, months: @months).call.map do |m|
          running += m[:balance_cents]
          {
            label:        m[:label],
            inflow_cents:  m[:income_cents],
            outflow_cents: m[:expense_cents],
            net_cents:     m[:balance_cents],
            accumulated_cents: running
          }
        end
      end
    end
  end
end
