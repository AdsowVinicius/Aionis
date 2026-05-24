class FinancialTransaction < ApplicationRecord
  belongs_to :workspace
  # document_id, counterparty_id e category_id são TODOS opcionais
  belongs_to :document,     optional: true
  belongs_to :counterparty, optional: true
  belongs_to :category,     optional: true

  enum :kind,   { income: "income", expense: "expense" }
  enum :origin, { manual: "manual", document: "document", import: "import" }
  enum :status, {
    pending: "pending",
    classified: "classified",
    confirmed: "confirmed",
    cancelled: "cancelled"
  }

  validates :kind, :description, :amount_cents, :origin, :status, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }

  def amount_brl
    (amount_cents || 0) / 100.0
  end

  # Aceita "120", "120,50", "120.50", "1.200,50"
  # Regra: se há vírgula, pontos são separadores de milhar; caso contrário, ponto é decimal.
  def amount_brl=(value)
    return if value.blank?
    sanitized = value.to_s.gsub(/[^\d.,]/, "").strip
    sanitized = if sanitized.include?(",")
                  sanitized.gsub(".", "").gsub(",", ".")
                else
                  sanitized
                end
    self.amount_cents = BigDecimal(sanitized).mult(100, 10).to_i
  rescue ArgumentError, TypeError
    # amount_cents permanece; validação capturará valor ausente/inválido
  end
end
