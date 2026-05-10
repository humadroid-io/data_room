class CreatePageViews < ActiveRecord::Migration[8.1]
  def change
    create_table :page_views do |t|
      t.references :investor, null: false, foreign_key: true
      t.references :page, null: false, foreign_key: true
      t.datetime   :viewed_at, null: false
      t.string     :ip_address
      t.timestamps

      t.index [:investor_id, :viewed_at]
      t.index [:page_id, :viewed_at]
    end
  end
end
