# frozen_string_literal: true

module Aionis
  module Analytics
    # Distribuição das despesas por essencialidade (essencial → supérfluo).
    class EssentialityBreakdown < Base
      LABELS = FinancialTransaction::ESSENTIALITIES # essential/operational_important/non_essential/superfluous/review

      Result = Struct.new(
        :total_cents, :by_essentiality, :essential_cents, :superfluous_cents,
        :essential_ratio, :superfluous_ratio, :unclassified_cents,
        keyword_init: true
      )

      def call
        grouped = expenses.group(:essentiality).sum(:amount_cents)
        grouped = grouped.transform_values(&:to_i)
        total   = grouped.values.sum

        by = LABELS.index_with { |k| grouped[k].to_i }

        essential   = by["essential"].to_i + by["operational_important"].to_i
        superfluous = by["superfluous"].to_i + by["non_essential"].to_i

        Result.new(
          total_cents:       total,
          by_essentiality:   by,
          essential_cents:   essential,
          superfluous_cents: superfluous,
          essential_ratio:   pct(essential, total),
          superfluous_ratio: pct(superfluous, total),
          unclassified_cents: grouped[nil].to_i + by["review"].to_i
        )
      end
    end
  end
end
