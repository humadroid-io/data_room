require "test_helper"

class PageTest < ActiveSupport::TestCase
  should belong_to(:parent).class_name("Page").optional
  should have_many(:children).class_name("Page").dependent(:destroy)
  should have_many(:page_views).dependent(:destroy)
  should have_many(:page_accesses).dependent(:destroy)
  should have_many(:allowed_investors).through(:page_accesses)
  should have_many(:page_redirects).dependent(:destroy)
  should define_enum_for(:visibility).with_values(draft: 0, public: 1, private: 2).with_prefix(:visibility)

  test "computes path for root landing" do
    landing = create(:landing_page)
    assert_equal "/", landing.path
  end

  test "computes path for top-level section" do
    page = create(:section_page, slug: "company")
    assert_equal "/company", page.path
  end

  test "computes nested path" do
    parent = create(:section_page, slug: "metrics")
    child  = create(:child_page, slug: "growth", parent_page: parent)
    assert_equal "/metrics/growth", child.path
  end

  test "rejects invalid slug" do
    page = build(:page, slug: "Bad Slug!")
    assert_not page.valid?
    assert page.errors[:slug].any?
  end

  test "creates redirect when path changes" do
    page = create(:section_page, slug: "old")
    assert_difference -> { PageRedirect.count }, 1 do
      page.update!(slug: "new")
    end
    assert_equal "/old", PageRedirect.last.old_path
    assert_equal page.id, PageRedirect.last.page_id
  end

  test "recomputes descendant paths when parent path changes" do
    parent = create(:section_page, slug: "old-parent")
    child  = create(:child_page, slug: "leaf", parent_page: parent)
    assert_equal "/old-parent/leaf", child.path

    parent.update!(slug: "new-parent")
    assert_equal "/new-parent/leaf", child.reload.path
  end

  test "draft page is invisible to every investor" do
    page = create(:draft_page, slug: "draft")
    assert_not page.visible_to?(create(:investor))
  end

  test "public page is visible to every investor" do
    page = create(:section_page, slug: "open")
    assert page.visible_to?(create(:investor))
  end

  test "private page is visible only to allowlisted investors" do
    page = create(:private_page, slug: "secret")
    allowed = create(:investor)
    other   = create(:investor)
    create(:page_access, page: page, investor: allowed)

    assert page.visible_to?(allowed)
    assert_not page.visible_to?(other)
  end

  test "saving a non-private page wipes any stray allowlist rows" do
    page = create(:private_page, slug: "x")
    create(:page_access, page: page, investor: create(:investor))
    assert page.page_accesses.exists?

    page.update!(visibility: :public)
    assert_not page.page_accesses.exists?
  end

  test "live scope returns public + private but not draft" do
    public_p  = create(:section_page, slug: "p", visibility: :public)
    private_p = create(:section_page, slug: "q", visibility: :private)
    draft_p   = create(:section_page, slug: "r", visibility: :draft)

    live = Page.live.to_a
    assert_includes     live, public_p
    assert_includes     live, private_p
    assert_not_includes live, draft_p
  end

  test "visible_children_for filters drafts and unallowed private pages" do
    parent = create(:section_page, slug: "parent")
    public_child  = create(:child_page, slug: "pub",     parent_page: parent)
    draft_child   = create(:child_page, slug: "draft",   parent_page: parent, visibility: :draft)
    private_child = create(:child_page, slug: "private", parent_page: parent, visibility: :private)

    investor = create(:investor)
    create(:page_access, page: private_child, investor: investor)

    other_investor = create(:investor)

    assert_includes     parent.visible_children_for(investor), public_child
    assert_includes     parent.visible_children_for(investor), private_child
    assert_not_includes parent.visible_children_for(investor), draft_child

    assert_includes     parent.visible_children_for(other_investor), public_child
    assert_not_includes parent.visible_children_for(other_investor), private_child
  end

  test "Page.landing returns the page at /" do
    landing = create(:landing_page)
    assert_equal landing, Page.landing
  end

  test "rejects two pages with the same path" do
    create(:section_page, slug: "company")
    duplicate = build(:section_page, slug: "company")
    assert_not duplicate.valid?
    assert duplicate.errors[:path].any?
  end
end
