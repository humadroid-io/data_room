class CreatePageRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :page_redirects do |t|
      t.references :page, null: false, foreign_key: true
      t.string     :old_path, null: false
      t.timestamps

      t.index :old_path, unique: true
    end
  end
end
