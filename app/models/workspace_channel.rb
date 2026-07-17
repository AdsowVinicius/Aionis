class WorkspaceChannel < ApplicationRecord
  belongs_to :workspace
  has_many :incoming_messages, dependent: :destroy
  has_many :outgoing_messages, dependent: :destroy

  # Segredos por workspace ficam criptografados em repouso (chaves via ENV).
  encrypts :access_token
  encrypts :refresh_token

  enum :channel_type, { whatsapp: "whatsapp" }, default: "whatsapp"
  enum :status, { pending: "pending", connected: "connected", disconnected: "disconnected" }

  validates :channel_type, :provider, presence: true
  validates :instance,        uniqueness: true, allow_nil: true
  validates :phone_number_id, uniqueness: true, allow_nil: true
  validates :instance,        presence: true, if: :evolution?  # Evolution usa instance
  validates :phone_number_id, presence: true, if: :meta?       # Meta usa phone_number_id

  scope :active, -> { where(active: true) }

  def meta?      = provider == "meta_cloud"
  def evolution? = provider == "evolution"

  # Credenciais passadas por chamada ao provider (o provider nunca conhece o model).
  def credentials
    {
      access_token:    access_token,
      refresh_token:   refresh_token,
      phone_number_id: phone_number_id,
      instance:        instance
    }
  end

  def touch_event!
    update_columns(last_event_at: Time.current, updated_at: Time.current)
  end
end
