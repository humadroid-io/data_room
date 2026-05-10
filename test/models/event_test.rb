require "test_helper"

class EventTest < ActiveSupport::TestCase
  should validate_presence_of(:title)
  should validate_presence_of(:occurred_on)
  should define_enum_for(:kind).with_values(
    funding: 0, launch: 1, hire: 2, partnership: 3, milestone: 4, risk: 5, other: 6
  ).with_prefix(:kind)

  test "default kind is :other" do
    event = Event.new(title: "T", occurred_on: Date.current)
    assert_equal "other", event.kind
  end

  test "color matches the kind" do
    assert_equal "#16a34a", build(:event, kind: :funding).color
    assert_equal "#dc2626", build(:event, kind: :risk).color
    assert_equal "#525252", build(:event, kind: :other).color
  end

  test "month_bucket formats the date as YYYY-MM" do
    event = build(:event, occurred_on: Date.new(2026, 5, 23))
    assert_equal "2026-05", event.month_bucket
  end

  test "chronological scope orders by occurred_on ascending" do
    older = create(:event, occurred_on: Date.new(2026, 1, 1))
    newer = create(:event, occurred_on: Date.new(2026, 5, 1))
    assert_equal [ older, newer ], Event.chronological.to_a
  end

  test "in_period scope filters by date range" do
    create(:event, occurred_on: Date.new(2025, 12, 1), title: "before")
    inside = create(:event, occurred_on: Date.new(2026, 3, 1), title: "inside")
    create(:event, occurred_on: Date.new(2026, 7, 1), title: "after")

    found = Event.in_period(Date.new(2026, 1, 1), Date.new(2026, 6, 30))
    assert_equal [ inside ], found.to_a
  end
end
