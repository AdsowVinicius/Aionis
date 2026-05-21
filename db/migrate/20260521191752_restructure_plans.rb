class RestructurePlans < ActiveRecord::Migration[8.1]
  def up
    rename_column :plans, :price_cents, :monthly_price_cents
    remove_column :plans, :features
    remove_column :plans, :active

    add_column :plans, :setup_fee_cents,             :integer, null: false, default: 0
    add_column :plans, :max_documents_month,         :integer
    add_column :plans, :max_whatsapp_messages_month, :integer
    add_column :plans, :max_users,                   :integer
    add_column :plans, :includes_email_channel,      :boolean, null: false, default: false
    add_column :plans, :includes_kpi_advanced,       :boolean, null: false, default: false
    add_column :plans, :includes_open_finance,       :boolean, null: false, default: false
    add_column :plans, :status,                      :string,  null: false, default: "active"

    add_index :plans, :status
  end

  def down
    remove_index :plans, :status
    remove_column :plans, :status
    remove_column :plans, :includes_open_finance
    remove_column :plans, :includes_kpi_advanced
    remove_column :plans, :includes_email_channel
    remove_column :plans, :max_users
    remove_column :plans, :max_whatsapp_messages_month
    remove_column :plans, :max_documents_month
    remove_column :plans, :setup_fee_cents

    add_column :plans, :active,   :boolean, null: false, default: true
    add_column :plans, :features, :jsonb,   null: false, default: {}
    rename_column :plans, :monthly_price_cents, :price_cents
  end
end
