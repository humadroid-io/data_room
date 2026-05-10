class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :customer, null: false, foreign_key: true
      t.string     :stripe_customer_id, null: false
      t.string     :stripe_subscription_id, null: false
      t.string     :product_code, null: false
      t.integer    :mrr_cents, null: false, default: 0
      t.string     :currency, default: "usd", null: false
      t.integer    :status, default: 0, null: false
      t.datetime   :started_at
      t.datetime   :canceled_at
      t.datetime   :paused_at
      t.datetime   :last_synced_at
      t.json       :custom_attributes, default: {}
      t.timestamps

      t.index :stripe_subscription_id, unique: true
      t.index :stripe_customer_id
      t.index [:status, :product_code]
    end
  end
end
