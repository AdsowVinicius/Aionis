# frozen_string_literal: true

module Aionis
  module Analytics
    # Evolução mensal de receitas, despesas e saldo nos últimos N meses.
    class MonthlyEvolution < Base
      def initialize(workspace, on: Date.current, months: 12)
        super(workspace, on: on)
        @months = months
      end

      def call
        last_months(@months).map do |from, to, label|
          scope   = in_range(realized, from, to)
          income  = sum_cents(scope.where(kind: "income"))
          expense = sum_cents(scope.where(kind: "expense"))
          { label: label, income_cents: income, expense_cents: expense, balance_cents: income - expense }
        end
      end
    end
  end
end
