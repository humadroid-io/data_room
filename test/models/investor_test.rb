require "test_helper"

class InvestorTest < ActiveSupport::TestCase
  subject { build(:investor) }

  should have_many(:page_views).dependent(:destroy)
  should have_many(:page_accesses).dependent(:destroy)
  should validate_presence_of(:name)
  should validate_uniqueness_of(:access_code)

  test "auto-generates an access code on create when blank" do
    inv = build(:investor, access_code: nil)
    assert inv.valid?
    assert inv.access_code.present?
    assert inv.access_code.length >= 6
  end

  test "respects an admin-supplied access code" do
    inv = create(:investor, access_code: "spring-2026")
    assert_equal "spring-2026", inv.reload.access_code
  end

  test "rejects too-short access code" do
    inv = build(:investor, access_code: "abc")
    assert_not inv.valid?
    assert inv.errors[:access_code].any?
  end

  test "rejects access code with disallowed characters" do
    inv = build(:investor, access_code: "has spaces!")
    assert_not inv.valid?
  end

  test "regenerate_access_code! changes the code" do
    inv = create(:investor, access_code: "old-code-1")
    old = inv.access_code
    inv.regenerate_access_code!
    refute_equal old, inv.access_code
  end

  test "defaults watermark from name + fund on create" do
    inv = build(:investor, name: "Alex", fund_name: "VC Fund", watermark_label: nil)
    inv.valid?
    assert_equal "Alex — VC Fund", inv.watermark_label
  end

  test "email is optional but must be unique when present" do
    create(:investor, email: "taken@example.com")
    duplicate = build(:investor, email: "taken@example.com")
    assert_not duplicate.valid?

    blank_email = build(:investor, email: nil)
    assert blank_email.valid?
  end

  test "usable scope excludes inactive" do
    active   = create(:investor)
    inactive = create(:investor, active: false)

    assert_includes Investor.usable, active
    assert_not_includes Investor.usable, inactive
  end

  test "usable scope excludes expired" do
    expired = create(:investor, access_expires_at: 1.day.ago)

    assert_not_includes Investor.usable, expired
    assert_not expired.usable?
  end
end
