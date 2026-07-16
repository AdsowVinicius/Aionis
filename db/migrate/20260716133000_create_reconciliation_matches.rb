class CreateReconciliationMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :reconciliation_matches do |t|
      t.bigint  :workspace_id,             null: false
      t.bigint  :bank_transaction_id,      null: false
      t.bigint  :financial_transaction_id, null: false
      t.integer :score,      null: false, default: 0
      t.string  :status,     null: false, default: "suggested" # suggested/confirmed/rejected
      t.string  :matched_by, null: false, default: "system"    # system/user
      t.jsonb   :reasons,    null: false, default: []

      t.timestamps
    end

    add_index :reconciliation_matches, :workspace_id
    add_index :reconciliation_matches, :bank_transaction_id
    add_index :reconciliation_matches, :financial_transaction_id
  end
end
