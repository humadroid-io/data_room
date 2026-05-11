require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup { @me = sign_in_admin }

  # --- show -----------------------------------------------------------------

  test "GET /admin renders" do
    get admin_root_path
    assert_response :success
    assert_select "ul[aria-label=?] a[href=?]", "Mobile admin navigation", admin_pages_path, text: "Pages"
  end

  test "GET /admin/dashboard renders" do
    get admin_dashboard_path
    assert_response :success
  end

  test "show includes a clear link to the public data room" do
    get admin_root_path
    assert_select "a[href=?]", root_path, text: "Visit data room"
  end

  test "show requires admin sign-in" do
    delete admin_logout_path
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "show renders page counts splitting drafts from live ones" do
    create(:section_page, slug: "live-1", visibility: :public)
    create(:section_page, slug: "live-2", visibility: :private)
    create(:section_page, slug: "draft",  visibility: :draft)

    get admin_root_path
    body = squish(response.body)
    assert_match("Pages</div> <div class=\"text-2xl font-semibold tabular-nums\">3", body)
    assert_match(/2 live \(public \+ private\)/, body)
  end

  test "show counts only usable investors" do
    create(:investor, name: "Active")
    create(:investor, name: "Inactive", active: false)
    create(:investor, name: "Expired",  access_expires_at: 1.day.ago)

    get admin_root_path
    body = squish(response.body)
    assert_match("Investors</div> <div class=\"text-2xl font-semibold tabular-nums\">1", body)
  end

  test "show counts customers" do
    create_list(:customer, 3)
    get admin_root_path
    body = squish(response.body)
    assert_match("Customers</div> <div class=\"text-2xl font-semibold tabular-nums\">3", body)
  end

  test "show sums MRR only for active and trialing subscriptions" do
    customer = create(:customer)
    create(:subscription, customer: customer, mrr_cents: 50_000, status: :active)
    create(:subscription, customer: customer, mrr_cents: 30_000, status: :trialing)
    create(:subscription, customer: customer, mrr_cents: 99_999, status: :canceled)

    get admin_root_path
    body = squish(response.body)
    assert_match(/Active MRR.*\$800/, body)  # 80,000 cents = $800
  end

  test "show lists recent page views with the page path" do
    page = create(:section_page, slug: "specific-page")
    investor = create(:investor, name: "Investor One")
    create(:page_view, page: page, investor: investor, viewed_at: 1.minute.ago)

    get admin_root_path
    assert_match "Investor One", response.body
    assert_match "/specific-page", response.body
    assert_select "a[href=?]", page.path, text: "Public"
  end

  test "show caps the recent-views list at 10 rows" do
    page = create(:section_page, slug: "p")
    investor = create(:investor)
    12.times { |i| create(:page_view, page: page, investor: investor, viewed_at: i.minutes.ago) }

    get admin_root_path
    # 10 rows in <tbody>, count <tr> within the recent-views table
    assert_select "table tbody tr", { count: 10, minimum: 10 }
  end

  test "show works with no pages, investors, or customers" do
    get admin_root_path
    assert_response :success
    assert_match "No views yet", response.body
  end

  test "show renders the Stripe panel reflecting StripeConfig state" do
    StripeConfig.stubs(:configured?).returns(true)
    StripeConfig.stubs(:customer_import_mode).returns(:all)
    Rails.cache.stubs(:read).with("stripe:last_sync_at").returns(2.hours.ago)
    Rails.cache.stubs(:read).with("stripe:last_sync_summary").returns(customers: 5, subscriptions: 3)

    get admin_root_path
    assert_response :success
    body = response.body
    assert_match "Sync now", body
    assert_match ">All<", body
    assert_match "5 customers", body
  end

  test "show disables Sync now when API key is missing" do
    StripeConfig.stubs(:configured?).returns(false)
    get admin_root_path
    assert_select "form[action=?] button[disabled]", admin_stripe_syncs_path
  end

  test "show shows the current admin's MCP token when one is set" do
    @me.regenerate_api_token!
    get admin_root_path
    assert_match @me.api_token, response.body
  end

  test "show shows a Generate-token button when admin has no token yet" do
    @me.update!(api_token: nil)
    get admin_root_path
    assert_match(/Generate MCP token/, response.body)
  end

  # --- regenerate_token -----------------------------------------------------

  test "POST regenerate_token rotates the current admin's token" do
    @me.regenerate_api_token!
    old = @me.api_token

    post admin_regenerate_token_path
    assert_redirected_to admin_root_path
    refute_equal old, @me.reload.api_token
  end

  test "POST regenerate_token requires admin sign-in" do
    delete admin_logout_path
    post admin_regenerate_token_path
    assert_redirected_to admin_login_path
  end

  test "POST regenerate_token only ever rotates the caller's token, not other admins'" do
    other = create(:user)
    other.regenerate_api_token!
    other_token_before = other.api_token

    post admin_regenerate_token_path
    assert_equal other_token_before, other.reload.api_token
  end

  private

  def squish(html)
    html.gsub(/\s+/, " ")
  end
end
