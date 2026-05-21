class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string  :name,   null: false
      t.string  :kind,   null: false
      t.string  :tax_id
      t.string  :status, null: false, default: "active"
      t.bigint  :owner_id, null: false

      t.timestamps
    end

    add_index :workspaces, :owner_id
    add_foreign_key :workspaces, :users, column: :owner_id
  end
end
