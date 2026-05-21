class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      # workspace_id nullable = categoria global do sistema
      t.references :workspace, null: true, foreign_key: true
      t.string     :name,        null: false
      t.string     :kind,        null: false
      t.string     :cost_type
      t.string     :essentiality
      t.integer    :parent_id

      t.timestamps
    end

    add_index :categories, :parent_id
    add_index :categories, [:workspace_id, :name]
  end
end
