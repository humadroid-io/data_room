class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string  :title,       null: false
      t.text    :description
      t.date    :occurred_on, null: false
      t.integer :kind,        null: false, default: 6   # default: :other
      t.timestamps

      t.index :occurred_on
    end
  end
end
