class AddUsdCentsToMoneyTables < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :mrr_cents_usd,    :integer, null: false, default: 0
    add_column :payments,      :amount_cents_usd, :integer, null: false, default: 0
    add_column :snapshots,     :mrr_cents_usd,    :integer, null: false, default: 0

    add_index :subscriptions, :mrr_cents_usd
    add_index :payments,      :amount_cents_usd
    add_index :snapshots,     :mrr_cents_usd

    reversible do |dir|
      dir.up do
        Subscription.reset_column_information
        Subscription.find_each do |s|
          usd = CurrencyConverter.to_usd_cents(s.mrr_cents, s.currency || "usd")
          s.update_columns(mrr_cents_usd: usd)
        end

        Payment.reset_column_information
        Payment.find_each do |p|
          usd = CurrencyConverter.to_usd_cents(p.amount_cents, p.currency || "usd")
          p.update_columns(amount_cents_usd: usd)
        end

        Snapshot.reset_column_information
        Snapshot.find_each do |snap|
          currency = snap.subscription&.currency || "usd"
          usd = CurrencyConverter.to_usd_cents(snap.mrr_cents, currency)
          snap.update_columns(mrr_cents_usd: usd)
        end
      end
    end
  end
end
