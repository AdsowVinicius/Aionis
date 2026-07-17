class Insight < ApplicationRecord
  belongs_to :workspace

  SEVERITIES = %w[info warning critical].freeze

  enum :status, { active: "active", dismissed: "dismissed" }

  validates :kind, presence: true
  validates :severity, inclusion: { in: SEVERITIES }

  scope :recent, -> { order(generated_on: :desc, created_at: :desc) }
end
