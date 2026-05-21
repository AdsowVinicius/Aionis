class Document < ApplicationRecord
  belongs_to :workspace
  belongs_to :counterparty, optional: true
  has_many :financial_transactions, dependent: :nullify

  has_one_attached :file

  enum :status, {
    pending: "pending",
    processing: "processing",
    processed: "processed",
    failed: "failed",
    review: "review"
  }

  enum :source, {
    web: "web",
    email: "email",
    whatsapp: "whatsapp",
    manual: "manual"
  }

  validates :status, :source, presence: true
end
