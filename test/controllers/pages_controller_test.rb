require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landing  = create(:landing_page)
    @section  = create(:section_page, slug: "company")
    @child    = create(:child_page, slug: "team", parent_page: @section)
    @investor = create(:investor)
  end

  test "redirects to login when not signed in" do
    get root_path
    assert_redirected_to login_path
  end

  test "GET / shows landing page" do
    sign_in_investor(@investor)
    get root_path
    assert_response :success
  end

  test "GET nested path serves the correct page" do
    sign_in_investor(@investor)
    get "/company/team"
    assert_response :success
  end

  test "GET trailing slash normalizes" do
    sign_in_investor(@investor)
    get "/company/"
    assert_response :success
  end

  test "404 for nonexistent path" do
    sign_in_investor(@investor)
    get "/does-not-exist"
    assert_response :not_found
  end

  test "old path redirects via PageRedirect" do
    sign_in_investor(@investor)
    @section.update!(slug: "company-renamed")
    get "/company"
    assert_response :success
  end

  test "private page without allowlist entry returns 404" do
    @child.update!(visibility: :private)
    sign_in_investor(@investor)
    get "/company/team"
    assert_response :not_found
  end

  test "private page with allowlist entry is visible" do
    @child.update!(visibility: :private)
    create(:page_access, page: @child, investor: @investor)
    sign_in_investor(@investor)
    get "/company/team"
    assert_response :success
  end

  test "draft page is not findable for investors" do
    @child.update!(visibility: :draft)
    sign_in_investor(@investor)
    get "/company/team"
    assert_response :not_found
  end

  test "GET tracks page view" do
    sign_in_investor(@investor)
    assert_difference -> { PageView.count }, 1 do
      get root_path
    end
    view = PageView.last
    assert_equal @investor, view.investor
    assert_equal @landing,  view.page
  end

  test "expired investor cannot view" do
    expired = create(:investor, access_expires_at: 1.day.ago)
    sign_in_investor(expired)
    get root_path
    assert_redirected_to login_path
  end

  test "admin (no investor cookie) can view any public page" do
    sign_in_admin
    get "/company"
    assert_response :success
  end

  test "admin can view draft pages" do
    @child.update!(visibility: :draft)
    sign_in_admin
    get "/company/team"
    assert_response :success
  end

  test "admin can view private pages without being on the allowlist" do
    @child.update!(visibility: :private)
    sign_in_admin
    get "/company/team"
    assert_response :success
  end

  test "admin browsing does NOT create page views" do
    sign_in_admin
    assert_no_difference -> { PageView.count } do
      get root_path
    end
  end
end
