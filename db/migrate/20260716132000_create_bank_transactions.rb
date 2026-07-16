class CreateBankTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_transactions do |t|
      t.bigint  :workspace_id,    null: false
      t.bigint  :bank_account_id, null: false
      t.bigint  :financial_transaction_id           # conciliação confirmada
      t.string  :external_id,     null: false        # tx id no provedor
      t.bigint  :amount_cents,    null: false        # valor absoluto
      t.string  :direction,       null: false        # credit/debit
      t.date    :posted_on
      t.text    :description
      t.jsonb   :raw, null: false, default: {}
      t.string  :reconciliation_status, null: false, default: "pending" # pending/matched/ignored

      t.timestamps
    end

    add_index :bank_transactions, :workspace_id
    add_index :bank_transactions, :bank_account_id
    add_index :bank_transactions, :financial_transaction_id
    add_index :bank_transactions, :reconciliation_status
    add_index :bank_transactions, [:bank_account_id, :external_id], unique: true
  end
end
