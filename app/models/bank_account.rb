class BankAccount < ApplicationRecord
  belongs_to :workspace
  belongs_to :consent
  has_many :bank_transactions, dependent: :destroy

  KINDS = %w[checking savings credit other].freeze

  validates :external_id, presence: true,
            uniqueness: { scope: :consent_id }
  validates :kind, inclusion: { in: KINDS }, allow_blank: true

  def balance_brl
    (balance_cents || 0) / 100.0
  end
end
