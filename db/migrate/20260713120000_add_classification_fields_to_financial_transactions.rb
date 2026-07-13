class AddClassificationFieldsToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_transactions, :cost_type,                 :string
    add_column :financial_transactions, :essentiality,              :string
    add_column :financial_transactions, :scope,                     :string
    add_column :financial_transactions, :recurrence,                :string
    add_column :financial_transactions, :cost_center,               :string
    add_column :financial_transactions, :classification_confidence, :integer
    add_column :financial_transactions, :classification_source,     :string
    add_column :financial_transactions, :classification_reasons,    :jsonb, default: [], null: false
  end
end
