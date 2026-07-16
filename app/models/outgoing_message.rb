class OutgoingMessage < ApplicationRecord
  belongs_to :workspace
  belongs_to :workspace_channel
  belongs_to :incoming_message, optional: true

  enum :status, { pending: "pending", sent: "sent", failed: "failed" }

  validates :to_number, :body, presence: true

  def mark_sent!(provider_message_id)
    update!(status: "sent", provider_message_id: provider_message_id, sent_at: Time.current)
  end

  def mark_failed!(message)
    update!(status: "failed", error: message.to_s.truncate(500))
  end
end
