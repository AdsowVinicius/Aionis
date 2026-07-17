class CreateInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :insights do |t|
      t.bigint  :workspace_id, null: false
      t.string  :kind,     null: false
      t.string  :severity, null: false, default: "info" # info/warning/critical
      t.string  :title
      t.text    :message
      t.jsonb   :data, null: false, default: {}
      t.string  :status, null: false, default: "active" # active/dismissed
      t.date    :generated_on

      t.timestamps
    end

    add_index :insights, :workspace_id
    add_index :insights, [:workspace_id, :status]
    add_index :insights, [:workspace_id, :kind, :generated_on],
              unique: true, name: "index_insights_on_workspace_kind_day"
  end
end
