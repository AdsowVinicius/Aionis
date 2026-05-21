class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :plan,      null: false, foreign_key: true
      t.string     :status,    null: false, default: "trial"
      t.datetime   :starts_at
      t.datetime   :ends_at
      t.datetime   :trial_ends_at

      t.timestamps
    end

    add_index :subscriptions, [:workspace_id, :status]
  end
end
