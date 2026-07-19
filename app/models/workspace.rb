class Workspace < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: :owner_id
  has_many :workspace_users, dependent: :destroy
  has_many :users, through: :workspace_users
  has_one :subscription, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :counterparties, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :document_extractions, dependent: :destroy
  has_many :financial_transactions, dependent: :destroy
  has_many :workspace_channels, dependent: :destroy
  has_many :incoming_messages, dependent: :destroy
  has_many :outgoing_messages, dependent: :destroy
  has_many :consents, dependent: :destroy
  has_many :bank_accounts, dependent: :destroy
  has_many :bank_transactions, dependent: :destroy
  has_many :reconciliation_matches, dependent: :destroy
  has_many :ai_interactions, dependent: :nullify
  has_many :kpi_snapshots, dependent: :destroy
  has_many :insights, dependent: :destroy

  enum :kind, { cpf: "cpf", mei: "mei", empresa: "empresa" }
  enum :status, { active: "active", suspended: "suspended", trial: "trial" }

  validates :name, :kind, presence: true
  # tax_id NUNCA obrigatório
  validates :tax_id, cpf_cnpj: true, allow_blank: true
  # Número de WhatsApp que identifica o remetente no número global do Aionis.
  # Opcional; único quando informado (um número pertence a um workspace).
  validates :whatsapp_number, uniqueness: true, allow_blank: true

  before_validation :normalize_whatsapp_number
  after_create :add_owner_as_member

  private

  # Guarda apenas dígitos (com DDI), formato em que a Meta entrega o remetente.
  def normalize_whatsapp_number
    return if whatsapp_number.blank?

    self.whatsapp_number = whatsapp_number.to_s.gsub(/\D/, "").presence
  end

  def add_owner_as_member
    workspace_users.find_or_create_by(user: owner) { |wu| wu.role = "owner" }
  end
end
