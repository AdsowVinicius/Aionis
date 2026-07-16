class CreateWorkspaceChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_channels do |t|
      t.bigint  :workspace_id, null: false
      t.string  :channel_type, null: false, default: "whatsapp"
      t.string  :provider,     null: false, default: "evolution"
      t.string  :instance,     null: false      # nome da instância no provedor
      t.string  :phone                            # número da linha (opcional)
      t.string  :external_id
      t.string  :status,       null: false, default: "pending"
      t.string  :webhook_token                    # token por canal (opcional)
      t.jsonb   :settings,     null: false, default: {}
      t.datetime :last_event_at

      t.timestamps
    end

    add_index :workspace_channels, :workspace_id
    add_index :workspace_channels, :instance, unique: true
    add_index :workspace_channels, [:workspace_id, :channel_type]
  end
end
