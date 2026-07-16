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

  enum :kind, { cpf: "cpf", mei: "mei", empresa: "empresa" }
  enum :status, { active: "active", suspended: "suspended", trial: "trial" }

  validates :name, :kind, presence: true
  # tax_id NUNCA obrigatório
  validates :tax_id, cpf_cnpj: true, allow_blank: true

  after_create :add_owner_as_member

  private

  def add_owner_as_member
    workspace_users.find_or_create_by(user: owner) { |wu| wu.role = "owner" }
  end
end
