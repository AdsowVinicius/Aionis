class OutgoingMessage < ApplicationRecord
  belongs_to :workspace
  belongs_to :workspace_channel
  belongs_to :incoming_message, optional: true

  # Status de entrega da Meta Cloud (sent → delivered → read) ou falha.
  # dry_run: envio suprimido em desenvolvimento (WHATSAPP_DRY_RUN) — não foi à Meta.
  enum :status, {
    pending:   "pending",
    sent:      "sent",
    delivered: "delivered",
    read:      "read",
    failed:    "failed",
    dry_run:   "dry_run"
  }

  validates :to_number, :body, presence: true

  def mark_sent!(provider_message_id)
    update!(status: "sent", provider_message_id: provider_message_id, sent_at: Time.current)
  end

  # Envio suprimido pelo dry-run: registra o id sintético e a hora, sem ir à Meta.
  def mark_dry_run!(provider_message_id = nil)
    update!(status: "dry_run", provider_message_id: provider_message_id, sent_at: Time.current)
  end

  def mark_status!(status)
    return unless self.class.statuses.key?(status.to_s)
    # Não regride status (read não volta para delivered/sent).
    update!(status: status) if rank(status) > rank(self.status)
  end

  def mark_failed!(message)
    update!(status: "failed", error: message.to_s.truncate(500))
  end

  private

  def rank(status)
    %w[pending sent delivered read failed].index(status.to_s) || -1
  end
end
