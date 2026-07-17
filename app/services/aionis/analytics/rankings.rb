# frozen_string_literal: true

module Aionis
  module Analytics
    # Rankings de despesa: top categorias, fornecedores e centros de custo.
    # Por padrão sobre o mês corrente; passe period: :all para o acumulado.
    class Rankings < Base
      def initialize(workspace, on: Date.current, limit: 5, period: :month)
        super(workspace, on: on)
        @limit  = limit
        @period = period
      end

      def call
        { categories: top_categories, counterparties: top_counterparties, cost_centers: top_cost_centers }
      end

      def top_categories
        scoped.where(kind: "expense").where.not(category_id: nil)
              .joins(:category)
              .group("categories.id", "categories.name")
              .order(Arel.sql("SUM(financial_transactions.amount_cents) DESC"))
              .limit(@limit)
              .pluck("categories.name", Arel.sql("SUM(financial_transactions.amount_cents)"), Arel.sql("COUNT(financial_transactions.id)"))
              .map { |name, total, count| row(name, total, count) }
      end

      def top_counterparties
        scoped.where.not(counterparty_id: nil)
              .joins(:counterparty)
              .group("counterparties.id", "counterparties.name")
              .order(Arel.sql("SUM(financial_transactions.amount_cents) DESC"))
              .limit(@limit)
              .pluck("counterparties.name", Arel.sql("SUM(financial_transactions.amount_cents)"), Arel.sql("COUNT(financial_transactions.id)"))
              .map { |name, total, count| row(name, total, count) }
      end

      def top_cost_centers
        scoped.where(kind: "expense").where.not(cost_center: [nil, ""])
              .group(:cost_center)
              .order(Arel.sql("SUM(financial_transactions.amount_cents) DESC"))
              .limit(@limit)
              .pluck(:cost_center, Arel.sql("SUM(financial_transactions.amount_cents)"), Arel.sql("COUNT(financial_transactions.id)"))
              .map { |name, total, count| row(name, total, count) }
      end

      private

      def scoped
        return realized if @period == :all
        from, to = month_range(on)
        in_range(realized, from, to)
      end

      def row(name, total, count)
        { name: name, total_cents: total.to_i, count: count.to_i }
      end
    end
  end
end
