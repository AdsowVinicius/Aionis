class AddMetaFieldsToWorkspaceChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :workspace_channels, :phone_number_id,      :string
    add_column :workspace_channels, :business_account_id,  :string
    add_column :workspace_channels, :display_phone_number, :string
    add_column :workspace_channels, :access_token,  :text   # criptografado (encrypts)
    add_column :workspace_channels, :refresh_token, :text   # criptografado (futuro)
    add_column :workspace_channels, :verify_token,   :string
    add_column :workspace_channels, :webhook_secret, :string
    add_column :workspace_channels, :active, :boolean, null: false, default: true

    # Meta usa phone_number_id como chave; Evolution usa instance. Relaxa a
    # obrigatoriedade de instance (mantém unicidade quando presente).
    change_column_null :workspace_channels, :instance, true
    add_index :workspace_channels, :phone_number_id, unique: true
  end
end
