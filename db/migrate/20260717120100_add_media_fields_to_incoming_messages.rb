class AddMediaFieldsToIncomingMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :incoming_messages, :media_url, :string
    add_column :incoming_messages, :mime_type, :string
  end
end
