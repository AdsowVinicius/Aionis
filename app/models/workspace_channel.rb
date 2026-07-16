class WorkspaceChannel < ApplicationRecord
  belongs_to :workspace
  has_many :incoming_messages, dependent: :destroy
  has_many :outgoing_messages, dependent: :destroy

  enum :channel_type, { whatsapp: "whatsapp" }, default: "whatsapp"
  enum :status, { pending: "pending", connected: "connected", disconnected: "disconnected" }

  validates :instance, presence: true, uniqueness: true
  validates :channel_type, :provider, presence: true

  scope :active, -> { where.not(status: "disconnected") }

  def touch_event!
    update_columns(last_event_at: Time.current, updated_at: Time.current)
  end
end
