class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :customer,     null: false, foreign_key: true
      t.references :subscription, foreign_key: true
      t.string     :stripe_invoice_id, null: false
      t.string     :stripe_charge_id
      t.integer    :amount_cents, null: false
      t.string     :currency, null: false, default: "usd"
      t.datetime   :paid_at, null: false
      t.timestamps

      t.index :stripe_invoice_id, unique: true
      t.index :paid_at
    end
  end
end
