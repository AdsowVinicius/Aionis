class AddOriginToCategoryRules < ActiveRecord::Migration[8.1]
  def change
    # origin: procedência da regra.
    #   "seed"    -> regra global carregada de config/aionis/category_rules.yml
    #   "manual"  -> criada/editada manualmente pelo usuário (futura UI)
    #   "learned" -> aprendida automaticamente a partir de correções do usuário
    add_column :category_rules, :origin, :string, default: "manual", null: false

    # Quantas vezes uma regra aprendida foi reforçada por novas correções.
    add_column :category_rules, :times_reinforced, :integer, default: 0, null: false

    add_index :category_rules, [:workspace_id, :origin]
  end
end
