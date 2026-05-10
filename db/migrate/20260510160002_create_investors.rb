class CreateInvestors < ActiveRecord::Migration[8.1]
  def change
    create_table :investors do |t|
      t.string   :name, null: false
      t.string   :fund_name
      t.string   :email, null: false
      t.string   :password_digest, null: false
      t.string   :watermark_label, null: false
      t.datetime :access_expires_at
      t.datetime :last_login_at
      t.boolean  :active, default: true, null: false
      t.timestamps

      t.index :email, unique: true
    end
  end
end
