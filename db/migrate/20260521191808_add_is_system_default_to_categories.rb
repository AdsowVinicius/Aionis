class AddIsSystemDefaultToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :is_system_default, :boolean, null: false, default: false
  end
end
