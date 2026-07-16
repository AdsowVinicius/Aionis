class CreateOutgoingMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :outgoing_messages do |t|
      t.bigint  :workspace_id,         null: false
      t.bigint  :workspace_channel_id, null: false
      t.bigint  :incoming_message_id                # resposta a (opcional)
      t.string  :to_number, null: false
      t.text    :body,      null: false
      t.string  :status,    null: false, default: "pending" # pending/sent/failed
      t.string  :provider_message_id
      t.integer :attempts,  null: false, default: 0
      t.text    :error
      t.datetime :sent_at

      t.timestamps
    end

    add_index :outgoing_messages, :workspace_id
    add_index :outgoing_messages, :workspace_channel_id
    add_index :outgoing_messages, :status
  end
end
