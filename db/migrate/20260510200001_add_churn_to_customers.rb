class AddChurnToCustomers < ActiveRecord::Migration[8.1]
  def change
    add_column :customers, :churned_on,           :date
    add_column :customers, :churn_reason_category, :integer
    add_column :customers, :churn_reason_notes,   :text

    add_index :customers, :churned_on
    add_index :customers, :churn_reason_category
  end
end
