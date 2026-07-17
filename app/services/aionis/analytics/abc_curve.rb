# frozen_string_literal: true

module Aionis
  module Analytics
    # Curva ABC das despesas por categoria: ordena por valor, calcula o
    # percentual acumulado e classifica em A (até 80%), B (até 95%) e C.
    class AbcCurve < Base
      def initialize(workspace, on: Date.current, period: :all)
        super(workspace, on: on)
        @period = period
      end

      def call
        rows = scoped.where(kind: "expense").where.not(category_id: nil)
                     .joins(:category)
                     .group("categories.id", "categories.name")
                     .order(Arel.sql("SUM(financial_transactions.amount_cents) DESC"))
                     .pluck("categories.name", Arel.sql("SUM(financial_transactions.amount_cents)"))

        total = rows.sum { |(_, v)| v.to_i }
        cumulative = 0

        rows.map do |name, value|
          value = value.to_i
          cumulative += value
          cum_pct = pct(cumulative, total)
          { name: name, total_cents: value, share_pct: pct(value, total),
            cumulative_pct: cum_pct, klass: klass_for(cum_pct) }
        end
      end

      private

      def klass_for(cumulative_pct)
        return "A" if cumulative_pct <= 80
        return "B" if cumulative_pct <= 95
        "C"
      end

      def scoped
        return realized if @period == :all
        from, to = month_range(on)
        in_range(realized, from, to)
      end
    end
  end
end
