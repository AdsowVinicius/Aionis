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

  validate :document_belongs_to_workspace,     if: -> { document_id.present? }
  validate :counterparty_belongs_to_workspace, if: -> { counterparty_id.present? }
  validate :category_allowed_for_workspace,    if: -> { category_id.present? }

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

  private

  def document_belongs_to_workspace
    return if workspace_id.blank?
    unless Document.where(id: document_id, workspace_id: workspace_id).exists?
      errors.add(:document, "não pertence a este workspace")
    end
  end

  def counterparty_belongs_to_workspace
    return if workspace_id.blank?
    unless Counterparty.where(id: counterparty_id, workspace_id: workspace_id).exists?
      errors.add(:counterparty, "não pertence a este workspace")
    end
  end

  def category_allowed_for_workspace
    return if workspace_id.blank?
    unless Category.where(id: category_id).where("workspace_id IS NULL OR workspace_id = ?", workspace_id).exists?
      errors.add(:category, "não pertence a este workspace")
    end
  end
end
