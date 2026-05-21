class FinancialTransaction < ApplicationRecord
  belongs_to :workspace
  # document_id, counterparty_id e category_id são TODOS opcionais
  belongs_to :document,    optional: true
  belongs_to :counterparty, optional: true
  belongs_to :category,    optional: true

  enum :kind,   { income: "income", expense: "expense" }
  enum :origin, { manual: "manual", document: "document", import: "import" }
  enum :status, {
    pending: "pending",
    classified: "classified",
    confirmed: "confirmed",
    cancelled: "cancelled"
  }

  validates :kind, :description, :amount_cents, :origin, :status, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }

  def amount_brl
    amount_cents / 100.0
  end
end
