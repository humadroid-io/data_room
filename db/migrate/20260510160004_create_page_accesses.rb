class CreatePageAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :page_accesses do |t|
      t.references :page, null: false, foreign_key: true
      t.references :investor, null: false, foreign_key: true
      t.integer    :mode, default: 0, null: false
      t.timestamps

      t.index [:page_id, :investor_id], unique: true
    end
  end
end
