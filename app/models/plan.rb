class Plan < ApplicationRecord
  has_many :subscriptions, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }

  def price_brl
    price_cents / 100.0
  end
end
