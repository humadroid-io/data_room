require "test_helper"

class SnapshotTest < ActiveSupport::TestCase
  should belong_to(:subscription)
  should validate_presence_of(:snapshot_date)

  test "cannot have two snapshots on same date for same subscription" do
    sub = create(:subscription)
    create(:snapshot, subscription: sub, snapshot_date: Date.new(2026, 1, 1))
    duplicate = build(:snapshot, subscription: sub, snapshot_date: Date.new(2026, 1, 1))
    assert_not duplicate.valid?
  end

  test "captured_attribute returns string value" do
    snap = create(:snapshot, captured_attributes: { "stage" => "implementation" })
    assert_equal "implementation", snap.captured_attribute(:stage)
  end
end
