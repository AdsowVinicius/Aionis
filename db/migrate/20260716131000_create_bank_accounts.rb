class CreateBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_accounts do |t|
      t.bigint  :workspace_id, null: false
      t.bigint  :consent_id,   null: false
      t.string  :external_id,  null: false        # account id no provedor
      t.string  :name
      t.string  :institution
      t.string  :branch
      t.string  :number
      t.string  :kind                              # checking/savings/credit
      t.string  :currency, null: false, default: "BRL"
      t.bigint  :balance_cents
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :bank_accounts, :workspace_id
    add_index :bank_accounts, :consent_id
    add_index :bank_accounts, [:consent_id, :external_id], unique: true
  end
end
