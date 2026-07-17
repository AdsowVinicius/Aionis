class CreateKpiSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :kpi_snapshots do |t|
      t.bigint  :workspace_id, null: false
      t.string  :period_label, null: false          # ex.: "2026-07"
      t.date    :period_start
      t.date    :period_end
      t.date    :captured_on
      t.bigint  :income_cents,  null: false, default: 0
      t.bigint  :expense_cents, null: false, default: 0
      t.bigint  :balance_cents, null: false, default: 0
      t.integer :health_score
      t.bigint  :burn_rate_cents
      t.jsonb   :data, null: false, default: {}

      t.timestamps
    end

    add_index :kpi_snapshots, :workspace_id
    add_index :kpi_snapshots, [:workspace_id, :period_label], unique: true
  end
end
