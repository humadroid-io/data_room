require "test_helper"

class McpToolsTest < ActiveSupport::TestCase
  setup do
    @ctx = { admin: create(:user) }
  end

  def parse(response)
    JSON.parse(response.content.first[:text])
  end

  # --- ListPagesTool ----------------------------------------------------------

  test "ListPagesTool returns all pages by default" do
    create(:section_page, slug: "p")
    create(:section_page, slug: "draft", visibility: :draft)

    response = ListPagesTool.call(server_context: @ctx)
    paths = parse(response)["pages"].map { |p| p["path"] }

    assert_includes paths, "/p"
    assert_includes paths, "/draft"
  end

  test "ListPagesTool with live_only excludes drafts but keeps private" do
    create(:section_page, slug: "live")
    create(:section_page, slug: "private", visibility: :private)
    create(:section_page, slug: "draft",   visibility: :draft)

    response = ListPagesTool.call(live_only: true, server_context: @ctx)
    paths = parse(response)["pages"].map { |p| p["path"] }

    assert_includes paths, "/live"
    assert_includes paths, "/private"
    assert_not_includes paths, "/draft"
  end

  # --- GetPageTool ------------------------------------------------------------

  test "GetPageTool fetches by path and includes body html" do
    page = create(:section_page, slug: "x", title: "Hello")
    page.body = "<p>World</p>"
    page.save!

    response = GetPageTool.call(path: "/x", server_context: @ctx)
    payload  = parse(response)

    assert_equal "Hello", payload["title"]
    assert_includes payload["body_html"], "World"
  end

  test "GetPageTool returns error when not found" do
    response = GetPageTool.call(path: "/nope", server_context: @ctx)
    assert response.error?
    assert_includes response.content.first[:text], "not found"
  end

  # --- CreatePageTool ---------------------------------------------------------

  test "CreatePageTool creates a public page" do
    response = CreatePageTool.call(
      title: "About", slug: "about", visibility: "public",
      body_html: "<p>Hello</p>",
      server_context: @ctx
    )
    payload = parse(response)
    page    = Page.find(payload["id"])
    assert_equal "/about", page.path
    assert page.visibility_public?
  end

  test "CreatePageTool creates a private page with allowlist" do
    investor = create(:investor)
    response = CreatePageTool.call(
      title: "Secret", slug: "secret", visibility: "private",
      allowed_investor_emails: [ investor.email ],
      server_context: @ctx
    )
    page = Page.find(parse(response)["id"])
    assert page.visibility_private?
    assert page.page_accesses.exists?(investor_id: investor.id)
  end

  test "CreatePageTool nests under parent_path" do
    parent = create(:section_page, slug: "company")

    response = CreatePageTool.call(
      title: "Team", slug: "team", parent_path: "/company",
      visibility: "public", server_context: @ctx
    )
    page = Page.find(parse(response)["id"])
    assert_equal parent, page.parent
    assert_equal "/company/team", page.path
  end

  test "CreatePageTool errors when parent_path is unknown" do
    response = CreatePageTool.call(
      title: "X", slug: "x", parent_path: "/missing", server_context: @ctx
    )
    assert response.error?
  end

  test "CreatePageTool surfaces validation errors" do
    response = CreatePageTool.call(title: "", slug: "Bad Slug!", server_context: @ctx)
    assert response.error?
    assert_includes response.content.first[:text], "Title"
  end

  # --- UpdatePageTool ---------------------------------------------------------

  test "UpdatePageTool changes visibility" do
    page = create(:section_page, slug: "old", title: "Old", visibility: :draft)

    UpdatePageTool.call(path: "/old", title: "New", visibility: "public", server_context: @ctx)

    page.reload
    assert_equal "New", page.title
    assert page.visibility_public?
  end

  test "UpdatePageTool can move a page under a new parent and creates redirect" do
    parent_a = create(:section_page, slug: "a")
    create(:section_page, slug: "b")
    page = create(:child_page, slug: "leaf", parent_page: parent_a)

    UpdatePageTool.call(path: "/a/leaf", parent_path: "/b", server_context: @ctx)

    assert_equal "/b/leaf", page.reload.path
    assert PageRedirect.exists?(old_path: "/a/leaf")
  end

  # --- DeletePageTool ---------------------------------------------------------

  test "DeletePageTool removes the page" do
    create(:section_page, slug: "byebye")

    DeletePageTool.call(path: "/byebye", server_context: @ctx)
    assert_nil Page.find_by(path: "/byebye")
  end

  # --- SetPageVisibilityTool --------------------------------------------------

  test "SetPageVisibilityTool grants access to a private page" do
    page     = create(:private_page, slug: "secret")
    investor = create(:investor)

    SetPageVisibilityTool.call(
      page_path: "/secret", investor_email: investor.email, allowed: true,
      server_context: @ctx
    )
    assert page.page_accesses.exists?(investor_id: investor.id)
  end

  test "SetPageVisibilityTool revokes access" do
    page     = create(:private_page, slug: "secret")
    investor = create(:investor)
    create(:page_access, page: page, investor: investor)

    SetPageVisibilityTool.call(
      page_path: "/secret", investor_email: investor.email, allowed: false,
      server_context: @ctx
    )
    assert_not page.page_accesses.exists?(investor_id: investor.id)
  end

  test "SetPageVisibilityTool errors when page is not private" do
    page = create(:section_page, slug: "open") # public
    investor = create(:investor)

    response = SetPageVisibilityTool.call(
      page_path: "/open", investor_email: investor.email, allowed: true,
      server_context: @ctx
    )
    assert response.error?
    assert_includes response.content.first[:text], "not private"
  end

  # --- ListInvestorsTool / ListCustomersTool ---------------------------------

  test "ListInvestorsTool returns investors without password digests" do
    create(:investor, name: "Bob")
    response = ListInvestorsTool.call(server_context: @ctx)
    payload  = parse(response)
    assert_equal "Bob", payload["investors"].first["name"]
    refute payload["investors"].first.key?("password_digest")
  end

  test "ListCustomersTool sums active mrr per customer" do
    customer = create(:customer)
    create(:subscription, customer: customer, mrr_cents: 5_000, status: :active)
    create(:subscription, customer: customer, mrr_cents: 9_000, status: :canceled)

    response = ListCustomersTool.call(server_context: @ctx)
    row = parse(response)["customers"].first
    assert_equal 5_000, row["active_mrr_cents"]
    assert_equal 2,     row["subscriptions_count"]
  end
end
