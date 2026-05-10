require "test_helper"

class Admin::InvestorsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "POST create auto-generates an access code" do
    assert_difference -> { Investor.count }, 1 do
      post admin_investors_path, params: {
        investor: { name: "Bob", email: "bob@example.com", watermark_label: "Bob" }
      }
    end
    assert Investor.last.access_code.present?
  end

  test "POST create accepts a custom access code" do
    post admin_investors_path, params: {
      investor: { name: "Bob", watermark_label: "Bob", access_code: "spring-2026" }
    }
    assert_equal "spring-2026", Investor.last.access_code
  end

  test "PATCH update changes name without touching access code" do
    investor = create(:investor)
    code_before = investor.access_code

    patch admin_investor_path(investor), params: {
      investor: { name: "Renamed" }
    }
    assert_equal code_before, investor.reload.access_code
    assert_equal "Renamed", investor.name
  end

  test "POST regenerate_access_code rotates the code" do
    investor = create(:investor)
    old_code = investor.access_code

    post regenerate_access_code_admin_investor_path(investor)
    refute_equal old_code, investor.reload.access_code
    assert_redirected_to edit_admin_investor_path(investor)
  end

  test "GET show renders detailed stats" do
    investor = create(:investor)
    page     = create(:section_page, slug: "p")
    create(:page_view, investor: investor, page: page, viewed_at: 2.days.ago)
    create(:page_view, investor: investor, page: page, viewed_at: 1.hour.ago)

    get admin_investor_path(investor)
    assert_response :success
    assert_match "/p", response.body
  end
end
