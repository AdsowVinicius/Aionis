class CreateIncomingMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :incoming_messages do |t|
      t.bigint  :workspace_id,         null: false
      t.bigint  :workspace_channel_id, null: false
      t.bigint  :document_id                      # documento gerado (se mídia)
      t.string  :wa_message_id,        null: false
      t.string  :from_number
      t.string  :push_name
      t.string  :kind,   null: false, default: "text"   # text/document/image/other
      t.text    :text
      t.string  :status, null: false, default: "received" # received/processed/failed/ignored
      t.jsonb   :payload, null: false, default: {}
      t.datetime :received_at

      t.timestamps
    end

    add_index :incoming_messages, :workspace_id
    add_index :incoming_messages, :workspace_channel_id
    add_index :incoming_messages, :document_id
    add_index :incoming_messages, [:workspace_channel_id, :wa_message_id], unique: true,
              name: "index_incoming_messages_on_channel_and_wa_id"
  end
end
