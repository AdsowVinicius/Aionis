class FinancialTransaction < ApplicationRecord
  belongs_to :workspace
  belongs_to :document,     optional: true
  belongs_to :counterparty, optional: true
  belongs_to :category,     optional: true

  enum :kind,   { income: "income", expense: "expense" }
  enum :origin, { manual: "manual", document: "document", import: "import" }
  enum :status, {
    pending:    "pending",
    classified: "classified",
    confirmed:  "confirmed",
    cancelled:  "cancelled"
  }
  # prefix: :settlement evita conflito com cancelled? do enum :status acima
  enum :settlement_status, {
    open:      "open",
    settled:   "settled",
    cancelled: "cancelled"
  }, prefix: :settlement

  validates :kind, :description, :amount_cents, :origin, :status, presence: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :due_on, presence: true, if: :settlement_status?

  validate :document_belongs_to_workspace,     if: -> { document_id.present? }
  validate :counterparty_belongs_to_workspace, if: -> { counterparty_id.present? }
  validate :category_allowed_for_workspace,    if: -> { category_id.present? }

  # Lançamentos realizados (sem settlement_status ou já liquidados)
  scope :realized,   -> { where(settlement_status: [nil, "settled"]) }
  # Contas a pagar (despesas abertas/programadas)
  scope :payables,   -> { where(kind: "expense", settlement_status: "open") }
  # Contas a receber (receitas abertas/programadas)
  scope :receivables, -> { where(kind: "income", settlement_status: "open") }
  # Vencidas: abertas com due_on < hoje
  scope :overdue,    -> { where(settlement_status: "open").where("due_on < ?", Date.current) }
  # Vencem em breve: abertas com due_on entre hoje e +7 dias
  scope :upcoming,   -> { where(settlement_status: "open").where(due_on: Date.current..7.days.from_now.to_date) }

  def amount_brl
    (amount_cents || 0) / 100.0
  end

  # Aceita "120", "120,50", "120.50", "1.200,50"
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
    nil
  end

  # Computado em runtime — não persiste em banco
  def overdue?
    settlement_open? && due_on.present? && due_on < Date.current
  end

  # Liquida a conta: marca settled, registra data, confirma o lançamento
  def settle!
    self.settlement_status = "settled"
    self.settled_on        = Date.current
    self.status            = "confirmed"
    self.transacted_on   ||= Date.current
    save!
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
