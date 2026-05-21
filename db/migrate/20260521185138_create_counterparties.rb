class CreateCounterparties < ActiveRecord::Migration[8.1]
  def change
    create_table :counterparties do |t|
      t.references :workspace,     null: false, foreign_key: true
      t.string     :name,          null: false
      t.string     :kind,          null: false
      # tax_id NUNCA null: false — CPF/CNPJ é opcional conforme regra do produto
      t.string     :tax_id
      t.string     :tax_id_status, null: false, default: "not_informed"
      t.string     :tax_id_source
      t.text       :notes

      t.timestamps
    end

    add_index :counterparties, [:workspace_id, :name]
    # Índice único só quando tax_id estiver preenchido (partial index)
    add_index :counterparties, [:workspace_id, :tax_id],
              unique: true,
              where: "tax_id IS NOT NULL",
              name: "index_counterparties_on_workspace_and_tax_id"
  end
end
