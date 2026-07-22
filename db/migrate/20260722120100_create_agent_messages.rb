class CreateAgentMessages < ActiveRecord::Migration[8.1]
  def change
    # Histórico do Agente Financeiro por workspace/canal. Alimenta a janela
    # deslizante do orquestrador (últimas N mensagens — nunca a conversa toda).
    create_table :agent_messages do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :channel, null: false, default: "portal" # portal | whatsapp
      t.string :role,    null: false                    # user | assistant
      t.text   :content, null: false
      t.jsonb  :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :agent_messages, [:workspace_id, :channel, :created_at]
  end
end
