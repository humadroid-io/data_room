class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.references :parent, foreign_key: { to_table: :pages }, index: true
      t.string  :slug, null: false
      t.string  :path, null: false
      t.string  :title, null: false
      t.integer :sort_order, default: 0, null: false
      t.boolean :published, default: false, null: false
      t.text    :tldr
      t.timestamps

      t.index :path, unique: true
      t.index [:parent_id, :sort_order]
    end
  end
end
