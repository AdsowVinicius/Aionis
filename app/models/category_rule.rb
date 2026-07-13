class CategoryRule < ApplicationRecord
  # workspace_id nulo = regra global do sistema
  belongs_to :workspace,    optional: true
  belongs_to :category,     optional: true
  belongs_to :counterparty, optional: true

  KINDS         = %w[income expense].freeze
  SCOPES        = %w[personal business mixed review].freeze
  RECURRENCES   = %w[recurring occasional one_off].freeze
  COST_TYPES    = %w[fixed variable semi_variable one_time].freeze
  ESSENTIALITIES = %w[essential operational_important non_essential superfluous review].freeze

  validates :name, presence: true
  validates :confidence, numericality: { in: 0..100 }
  validates :kind,         inclusion: { in: KINDS },          allow_blank: true
  validates :scope,        inclusion: { in: SCOPES },         allow_blank: true
  validates :recurrence,   inclusion: { in: RECURRENCES },    allow_blank: true
  validates :cost_type,    inclusion: { in: COST_TYPES },     allow_blank: true
  validates :essentiality, inclusion: { in: ESSENTIALITIES }, allow_blank: true

  scope :active,        -> { where(active: true) }
  scope :global,        -> { where(workspace_id: nil) }
  scope :for_workspace, ->(ws) { where(workspace_id: [ws&.id, nil]) }
  scope :by_priority,   -> { order(priority: :desc, id: :asc) }

  # Lista de palavras-chave normalizadas (minúsculas, sem acento)
  def keyword_list
    @keyword_list ||= keywords.to_s
                              .split(/[,;]/)
                              .map { |k| self.class.normalize(k) }
                              .reject(&:blank?)
  end

  def global?
    workspace_id.nil?
  end

  # Verdadeiro quando TODAS as condições preenchidas casam com o contexto.
  # Regra sem nenhuma condição nunca casa (evita "pega-tudo" acidental).
  def matches?(context)
    conditions = []
    conditions << kind_matches?(context)         unless kind.blank?
    conditions << counterparty_matches?(context) unless counterparty_id.blank?
    conditions << tax_id_matches?(context)       unless tax_id.blank?
    conditions << keywords_match?(context)       unless keyword_list.empty?

    return false if conditions.empty?
    conditions.all?
  end

  # Quantidade de condições satisfeitas — usado para especificidade/desempate.
  def match_strength(context)
    strength = 0
    strength += 1 if !kind.blank?            && kind_matches?(context)
    strength += 2 if !counterparty_id.blank? && counterparty_matches?(context)
    strength += 2 if !tax_id.blank?          && tax_id_matches?(context)
    strength += 1 if !keyword_list.empty?    && keywords_match?(context)
    strength
  end

  def self.normalize(text)
    I18n.transliterate(text.to_s.downcase).strip
  end

  private

  def kind_matches?(context)
    context.kind.to_s == kind.to_s
  end

  def counterparty_matches?(context)
    context.counterparty_id.present? && context.counterparty_id.to_i == counterparty_id.to_i
  end

  def tax_id_matches?(context)
    ctx = context.tax_id_digits.to_s
    ctx.present? && ctx == tax_id.to_s.gsub(/\D/, "")
  end

  def keywords_match?(context)
    text = self.class.normalize(context.description)
    return false if text.blank?
    keyword_list.any? { |kw| text.include?(kw) }
  end
end
