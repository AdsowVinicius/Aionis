class Consent < ApplicationRecord
  belongs_to :workspace
  has_many :bank_accounts, dependent: :destroy

  enum :status, {
    pending: "pending",
    active:  "active",
    revoked: "revoked",
    expired: "expired"
  }

  validates :provider, presence: true

  scope :usable, -> { where(status: "active") }
end
