class CreateDocumentExtractions < ActiveRecord::Migration[8.1]
  def change
    create_table :document_extractions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :document,  null: false, foreign_key: true
      t.string  :status,                        null: false, default: "pending"
      t.text    :raw_text
      t.jsonb   :extracted_data,                null: false, default: {}
      t.jsonb   :suggested_transaction_data,    null: false, default: {}
      t.integer :confidence_score
      t.string  :processor_name
      t.string  :processor_version
      t.text    :error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :document_extractions, [:workspace_id, :document_id]
    add_index :document_extractions, :status
  end
end
