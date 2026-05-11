class AddIntervalMonthsToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :interval_months, :integer, null: false, default: 1
  end
end
