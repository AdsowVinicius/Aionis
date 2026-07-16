class Category < ApplicationRecord
  include Auditable

  # workspace_id pode ser nil = categoria global do sistema
  belongs_to :workspace, optional: true
  belongs_to :parent, class_name: "Category", optional: true, foreign_key: :parent_id
  has_many :subcategories, class_name: "Category", foreign_key: :parent_id, dependent: :destroy
  has_many :financial_transactions, dependent: :nullify

  enum :kind, { income: "income", expense: "expense", transfer: "transfer" }

  enum :cost_type, {
    fixed: "fixed",
    variable: "variable",
    semi_variable: "semi_variable",
    one_time: "one_time"
  }, prefix: :cost

  enum :essentiality, {
    essential: "essential",
    operational_important: "operational_important",
    non_essential: "non_essential",
    superfluous: "superfluous",
    review: "review"
  }, prefix: :essentiality

  validates :name, :kind, presence: true

  scope :global,         -> { where(workspace_id: nil) }
  scope :system_default, -> { where(is_system_default: true) }
  scope :for_workspace,  ->(workspace) { where(workspace: workspace).or(global) }
end
