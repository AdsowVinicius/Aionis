class AddSettlementFieldsToFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :financial_transactions, :due_on,            :date
    add_column :financial_transactions, :settled_on,        :date
    add_column :financial_transactions, :settlement_status, :string
    add_column :financial_transactions, :notes,             :text

    add_index :financial_transactions,
              [ :workspace_id, :settlement_status, :due_on ],
              name: "index_financial_transactions_on_settlement"
  end
end
