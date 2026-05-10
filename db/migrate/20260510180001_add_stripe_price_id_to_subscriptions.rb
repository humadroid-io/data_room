class AddStripePriceIdToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :stripe_price_id, :string
    add_index  :subscriptions, :stripe_price_id

    change_column_null :subscriptions, :product_code, true

    reversible do |dir|
      dir.up do
        # Old "unknown" placeholder is no longer meaningful — clear it so
        # the new fallback (stripe_price_id) takes over once subs re-sync.
        Subscription.reset_column_information
        Subscription.where(product_code: "unknown").update_all(product_code: nil)
      end
    end
  end
end
