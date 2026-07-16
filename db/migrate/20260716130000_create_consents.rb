class CreateConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :consents do |t|
      t.bigint  :workspace_id, null: false
      t.string  :provider,     null: false, default: "pluggy"
      t.string  :external_id                       # item id no provedor
      t.string  :status,       null: false, default: "pending" # pending/active/revoked/expired
      t.text    :connect_token
      t.string  :redirect_url
      t.jsonb   :scopes,       null: false, default: []
      t.jsonb   :metadata,     null: false, default: {}
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :consents, :workspace_id
    add_index :consents, [:provider, :external_id]
  end
end
