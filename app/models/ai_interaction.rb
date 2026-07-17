class AiInteraction < ApplicationRecord
  belongs_to :workspace, optional: true
  belongs_to :financial_transaction, optional: true
  belongs_to :document, optional: true

  KINDS = %w[classification review completion].freeze

  validates :provider, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :recent, -> { order(created_at: :desc) }

  def total_tokens
    tokens_input.to_i + tokens_output.to_i
  end
end
