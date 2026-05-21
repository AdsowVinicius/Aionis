class Subscription < ApplicationRecord
  belongs_to :workspace
  belongs_to :plan

  enum :status, {
    trial: "trial",
    active: "active",
    past_due: "past_due",
    canceled: "canceled",
    expired: "expired"
  }

  validates :status, presence: true

  def active_or_trial?
    trial? || active?
  end
end
