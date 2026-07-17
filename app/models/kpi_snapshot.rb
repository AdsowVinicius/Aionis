class KpiSnapshot < ApplicationRecord
  belongs_to :workspace

  validates :period_label, presence: true, uniqueness: { scope: :workspace_id }

  scope :chronological, -> { order(:period_start) }

  def income_brl  = income_cents.to_i / 100.0
  def expense_brl = expense_cents.to_i / 100.0
  def balance_brl = balance_cents.to_i / 100.0
end
