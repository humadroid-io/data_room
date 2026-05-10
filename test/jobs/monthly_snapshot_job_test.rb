require "test_helper"

class MonthlySnapshotJobTest < ActiveJob::TestCase
  test "no-ops on day other than the 1st" do
    create(:subscription)
    travel_to Date.new(2026, 5, 15) do
      assert_no_difference -> { Snapshot.count } do
        MonthlySnapshotJob.perform_now
      end
    end
  end

  test "creates a snapshot per subscription on the 1st" do
    create(:captured_attribute, key: "stage")
    customer = create(:customer, custom_attributes: { "stage" => "stage1" })
    sub = create(:subscription, customer: customer, mrr_cents: 50_000)

    travel_to Date.new(2026, 6, 1) do
      assert_difference -> { Snapshot.count }, 1 do
        MonthlySnapshotJob.perform_now
      end
    end

    snap = sub.snapshots.last
    assert_equal Date.new(2026, 6, 1), snap.snapshot_date
    assert_equal 50_000, snap.mrr_cents
    assert_equal({ "stage" => "stage1" }, snap.captured_attributes)
  end

  test "force flag bypasses day check" do
    create(:subscription)
    travel_to Date.new(2026, 5, 15) do
      assert_difference -> { Snapshot.count }, 1 do
        MonthlySnapshotJob.perform_now(force: true)
      end
    end
  end

  test "is idempotent on the same day" do
    create(:subscription)
    travel_to Date.new(2026, 6, 1) do
      MonthlySnapshotJob.perform_now
      assert_no_difference -> { Snapshot.count } do
        MonthlySnapshotJob.perform_now
      end
    end
  end
end
