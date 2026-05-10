require "test_helper"

class PageAccessTest < ActiveSupport::TestCase
  should belong_to(:page)
  should belong_to(:investor)

  test "investor cannot have two allowlist rows on same page" do
    page = create(:private_page, slug: "p")
    investor = create(:investor)
    create(:page_access, page: page, investor: investor)
    duplicate = build(:page_access, page: page, investor: investor)
    assert_not duplicate.valid?
  end
end
