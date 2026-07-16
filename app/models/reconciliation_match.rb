class ReconciliationMatch < ApplicationRecord
  belongs_to :workspace
  belongs_to :bank_transaction
  belongs_to :financial_transaction

  enum :status, {
    suggested: "suggested",
    confirmed: "confirmed",
    rejected:  "rejected"
  }

  MATCHED_BY = %w[system user].freeze

  validates :score, numericality: { in: 0..100 }
  validates :matched_by, inclusion: { in: MATCHED_BY }

  scope :active, -> { where.not(status: "rejected") }
end
