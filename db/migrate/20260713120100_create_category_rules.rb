class CreateCategoryRules < ActiveRecord::Migration[8.1]
  def change
    create_table :category_rules do |t|
      # workspace_id nulo = regra global do sistema
      t.references :workspace, null: true, foreign_key: true

      t.string  :name, null: false
      t.integer :priority, null: false, default: 0
      t.boolean :active,   null: false, default: true

      # Condições de match (todas opcionais; combinadas com AND quando presentes)
      t.string  :kind                       # income / expense (nil = qualquer)
      t.string  :keywords                   # palavras separadas por vírgula (match na descrição)
      t.integer :counterparty_id            # fornecedor/cliente específico
      t.string  :tax_id                     # CPF/CNPJ (dígitos) do fornecedor

      # Resultados sugeridos
      t.integer :category_id
      t.string  :cost_type                  # override do cost_type da categoria
      t.string  :essentiality               # override da essentiality da categoria
      t.string  :scope                      # personal / business / mixed / review
      t.string  :recurrence                 # recurring / occasional / one_off
      t.string  :cost_center                # centro de custo sugerido

      t.integer :confidence, null: false, default: 70

      t.timestamps
    end

    add_index :category_rules, [:workspace_id, :active]
    add_index :category_rules, :priority
    add_index :category_rules, :counterparty_id
    add_index :category_rules, :tax_id
  end
end
