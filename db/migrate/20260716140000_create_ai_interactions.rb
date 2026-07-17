class CreateAiInteractions < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_interactions do |t|
      t.bigint  :workspace_id
      t.bigint  :financial_transaction_id
      t.bigint  :document_id
      t.string  :kind,     null: false, default: "classification"
      t.string  :provider, null: false
      t.string  :model
      t.text    :prompt
      t.text    :response
      t.integer :tokens_input,  null: false, default: 0
      t.integer :tokens_output, null: false, default: 0
      t.decimal :cost_cents, precision: 12, scale: 4, null: false, default: 0
      t.integer :duration_ms
      t.integer :confidence
      t.jsonb   :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :ai_interactions, [:workspace_id, :created_at]
    add_index :ai_interactions, :provider
    add_index :ai_interactions, :financial_transaction_id
  end
end
