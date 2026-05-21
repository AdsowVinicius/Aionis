class CreateFinancialTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_transactions do |t|
      t.references :workspace,   null: false, foreign_key: true
      t.string     :kind,        null: false
      t.string     :description, null: false
      t.integer    :amount_cents, null: false
      t.date       :transacted_on
      t.string     :origin,      null: false, default: "manual"
      t.string     :status,      null: false, default: "pending"
      # document_id, counterparty_id e category_id são TODOS opcionais
      t.integer    :document_id
      t.integer    :counterparty_id
      t.integer    :category_id
      # Snapshots para preservar dados no momento do lançamento
      t.string     :counterparty_name_snapshot
      t.string     :counterparty_tax_id_snapshot
      t.string     :counterparty_tax_id_status

      t.timestamps
    end

    add_index :financial_transactions, [:workspace_id, :status]
    add_index :financial_transactions, [:workspace_id, :transacted_on]
    add_index :financial_transactions, :document_id
    add_index :financial_transactions, :counterparty_id
    add_index :financial_transactions, :category_id
  end
end
