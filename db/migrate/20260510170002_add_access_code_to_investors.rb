class AddAccessCodeToInvestors < ActiveRecord::Migration[8.1]
  def change
    add_column :investors, :access_code, :string
    add_index  :investors, :access_code, unique: true

    reversible do |dir|
      dir.up do
        Investor.reset_column_information
        Investor.find_each do |inv|
          inv.update_column(:access_code, SecureRandom.urlsafe_base64(18))
        end
      end
    end

    change_column_null :investors, :access_code, false
    change_column_null :investors, :email, true
    remove_column :investors, :password_digest, :string
  end
end
