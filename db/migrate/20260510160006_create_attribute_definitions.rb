class CreateAttributeDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :attribute_definitions do |t|
      t.string  :resource_type, null: false
      t.string  :key, null: false
      t.string  :label, null: false
      t.text    :description
      t.integer :data_type, null: false
      t.json    :options
      t.boolean :required, default: false, null: false
      t.boolean :capture_on_snapshot, default: false, null: false
      t.integer :sort_order, default: 0, null: false
      t.timestamps

      t.index [:resource_type, :key], unique: true
      t.index [:resource_type, :sort_order]
    end
  end
end
