class CreateWorkspaceMemories < ActiveRecord::Migration[8.1]
  def change
    # Memória curada do Agente Financeiro: fatos compactos por workspace que
    # entram no system prompt (top-N por relevância, com teto de tokens).
    # NÃO é a conversa bruta acumulada — é um resumo estruturado e limitado.
    create_table :workspace_memories do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string  :key,    null: false      # ex: "ramo", "fornecedor_frequente", "preferencia"
      t.text    :value,  null: false
      t.string  :source, null: false, default: "system" # user_stated | inferred | system
      t.integer :relevance, null: false, default: 0     # prioriza o que injetar
      t.timestamps
    end
    add_index :workspace_memories, [:workspace_id, :key]
  end
end
