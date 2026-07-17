# frozen_string_literal: true

module Aionis
  module Analytics
    # Previsão simples dos próximos N meses por média móvel das receitas/despesas
    # dos últimos `lookback` meses. Saldo projetado é acumulado a partir do caixa atual.
    class Forecast < Base
      def initialize(workspace, on: Date.current, months: 3, lookback: 3)
        super(workspace, on: on)
        @months   = months
        @lookback = lookback
      end

      def call
        history = MonthlyEvolution.new(workspace, on: on, months: @lookback).call
        avg_income  = average(history.map { |m| m[:income_cents] })
        avg_expense = average(history.map { |m| m[:expense_cents] })
        running     = Kpis.new(workspace, on: on).call.general_balance_cents

        (1..@months).map do |i|
          month = on.beginning_of_month + i.months
          running += (avg_income - avg_expense)
          {
            label: month.strftime("%Y-%m"),
            projected_income_cents:  avg_income,
            projected_expense_cents: avg_expense,
            projected_balance_cents: running
          }
        end
      end

      private

      def average(values)
        return 0 if values.empty?
        (values.sum / values.size)
      end
    end
  end
end
