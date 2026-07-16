class Counterparty < ApplicationRecord
  include Auditable

  belongs_to :workspace
  has_many :documents, dependent: :nullify
  has_many :financial_transactions, dependent: :nullify

  enum :kind, { supplier: "supplier", client: "client", both: "both" }

  enum :tax_id_status, {
    not_informed: "not_informed",
    informed: "informed",
    verified: "verified",
    invalid: "invalid",
    skipped: "skipped"
  }, prefix: :tax_id

  enum :tax_id_source, {
    user_input: "user_input",
    ocr: "ocr",
    xml: "xml",
    bank_statement: "bank_statement",
    ai: "ai",
    import: "import"
  }, allow_nil: true

  validates :name, :kind, presence: true
  # tax_id validado APENAS quando preenchido — NUNCA exigido
  validates :tax_id, cpf_cnpj: true, allow_blank: true

  before_validation :update_tax_id_status

  private

  def update_tax_id_status
    if tax_id.blank?
      # Preserva "skipped" se o usuário escolheu pular explicitamente; do contrário, reset
      self.tax_id_status = "not_informed" unless tax_id_skipped?
    else
      # Preserva "verified" se já foi verificado manualmente
      self.tax_id_status = "informed" unless tax_id_verified?
    end
  end
end
