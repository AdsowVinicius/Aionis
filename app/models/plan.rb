class Plan < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_error

  enum :status, { active: "active", coming_soon: "coming_soon", archived: "archived" }

  validates :name, :slug, :status, presence: true
  validates :slug, uniqueness: true
  validates :monthly_price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :setup_fee_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def monthly_price_brl
    monthly_price_cents / 100.0
  end

  def setup_fee_brl
    (setup_fee_cents || 0) / 100.0
  end
end
