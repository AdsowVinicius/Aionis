class AddMetaFieldsToOutgoingMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :outgoing_messages, :message_type, :string, null: false, default: "text"
    add_column :outgoing_messages, :payload,  :jsonb, null: false, default: {}
    add_column :outgoing_messages, :metadata, :jsonb, null: false, default: {}
  end
end
