class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string  :name, null: false
      t.string  :anonymized_label
      t.string  :stripe_customer_id
      t.text    :notes
      t.boolean :reference_call_ok, default: false, null: false
      t.json    :custom_attributes, default: {}
      t.timestamps

      t.index :stripe_customer_id, unique: true
    end
  end
end
