class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string  :name,        null: false
      t.string  :slug,        null: false
      t.integer :price_cents, null: false, default: 0
      t.jsonb   :features,    null: false, default: {}
      t.boolean :active,      null: false, default: true

      t.timestamps
    end

    add_index :plans, :slug, unique: true
  end
end
