class CreateSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :snapshots do |t|
      t.references :subscription, null: false, foreign_key: true
      t.date       :snapshot_date, null: false
      t.integer    :mrr_cents, null: false
      t.integer    :status, null: false
      t.json       :captured_attributes, default: {}
      t.timestamps

      t.index [:subscription_id, :snapshot_date], unique: true
      t.index :snapshot_date
    end
  end
end
