# frozen_string_literal: true

module Aionis
  module Analytics
    # Base dos serviços de inteligência financeira. Concentra o escopo comum
    # (lançamentos realizados) e helpers de período/data. Toda regra de negócio
    # de analytics vive aqui e nas subclasses — nunca nos controllers.
    class Base
      # Data efetiva do lançamento (transacted_on, com fallback para created_at).
      DATE_SQL = "COALESCE(financial_transactions.transacted_on, financial_transactions.created_at::date)"

      def self.call(*args, **kwargs) = new(*args, **kwargs).call

      def initialize(workspace, on: Date.current)
        @workspace = workspace
        @on        = on
      end

      private

      attr_reader :workspace, :on

      # Lançamentos que realmente entraram no caixa: não cancelados e
      # (sem settlement_status OU já liquidados).
      def realized
        workspace.financial_transactions
                 .where.not(status: "cancelled")
                 .where(settlement_status: [nil, "settled"])
      end

      def expenses = realized.where(kind: "expense")
      def incomes  = realized.where(kind: "income")

      def in_range(relation, from, to)
        relation.where("#{DATE_SQL} BETWEEN ? AND ?", from, to)
      end

      def month_range(date)
        [date.beginning_of_month, date.end_of_month]
      end

      # Últimos N meses (mais antigo → mais recente), cada um como [inicio, fim, label].
      def last_months(count, ending: on)
        (0...count).to_a.reverse.map do |i|
          d = ending.beginning_of_month - i.months
          [d, d.end_of_month, d.strftime("%Y-%m")]
        end
      end

      def sum_cents(relation) = relation.sum(:amount_cents).to_i

      def pct(part, total)
        return 0.0 if total.to_f.zero?
        (part.to_f / total * 100).round(1)
      end
    end
  end
end
