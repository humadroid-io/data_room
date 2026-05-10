class MonthlySnapshotJob < ApplicationJob
  queue_as :default

  def perform(force: false)
    return unless force || Date.current.day == 1

    Subscription.find_each do |sub|
      next unless sub.customer

      Snapshot.find_or_create_by!(subscription: sub, snapshot_date: Date.current.beginning_of_month) do |snap|
        snap.mrr_cents           = sub.mrr_cents
        snap.status              = sub.status
        snap.captured_attributes = sub.customer.captured_attributes_for_snapshot
      end
    end
  end
end
