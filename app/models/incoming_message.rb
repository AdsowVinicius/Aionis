class IncomingMessage < ApplicationRecord
  belongs_to :workspace
  belongs_to :workspace_channel
  belongs_to :document, optional: true

  KINDS = %w[text document image other].freeze

  enum :status, {
    received:  "received",
    processed: "processed",
    failed:    "failed",
    ignored:   "ignored"
  }

  validates :wa_message_id, presence: true,
            uniqueness: { scope: :workspace_channel_id }
  validates :kind, inclusion: { in: KINDS }

  def media?
    kind.in?(%w[document image])
  end
end
