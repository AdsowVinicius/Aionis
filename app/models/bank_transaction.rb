class BankTransaction < ApplicationRecord
  belongs_to :workspace
  belongs_to :bank_account
  belongs_to :financial_transaction, optional: true
  has_many :reconciliation_matches, dependent: :destroy

  DIRECTIONS = %w[credit debit].freeze

  enum :reconciliation_status, {
    pending: "pending",
    matched: "matched",
    ignored: "ignored"
  }

  validates :external_id, presence: true, uniqueness: { scope: :bank_account_id }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :direction, inclusion: { in: DIRECTIONS }

  scope :unmatched, -> { where(reconciliation_status: "pending") }

  # Natureza correspondente no lançamento financeiro.
  def financial_kind
    direction == "credit" ? "income" : "expense"
  end

  def amount_brl
    (amount_cents || 0) / 100.0
  end
end
