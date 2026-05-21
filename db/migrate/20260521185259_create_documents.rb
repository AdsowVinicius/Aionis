class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :workspace,      null: false, foreign_key: true
      # counterparty_id opcional — documento pode não ter fornecedor identificado
      t.integer    :counterparty_id
      t.string     :status,         null: false, default: "pending"
      t.string     :source,         null: false, default: "web"
      t.text       :notes

      t.timestamps
    end

    add_index :documents, :counterparty_id
    add_index :documents, [:workspace_id, :status]
  end
end
