require "application_system_test_case"

class InvestorDataRoomTest < ApplicationSystemTestCase
  test "investor can sign in and sign out" do
    create(:landing_page, title: "Welcome")
    investor = create(:investor, name: "Investor One")

    sign_in_investor(investor)

    assert_current_path root_path
    assert_text "Welcome"
    assert_button "Sign out"

    click_button "Sign out"

    assert_current_path login_path
    assert_text "Signed out."
  end

  test "investor sees accessible pages in child-page widgets" do
    landing = create(:landing_page, title: "Overview")
    create(:section_page, slug: "metrics", title: "Metrics")
    private_page = create(:section_page, slug: "secret", title: "Secret", visibility: :private)
    create(:section_page, slug: "hidden", title: "Hidden", visibility: :private)
    investor = create(:investor)
    create(:page_access, investor: investor, page: private_page)

    landing.update!(body: "[CHILD_PAGES_2_COL]")

    sign_in_investor(investor)

    assert_text "Metrics"
    assert_text "Secret"
    assert_no_text "Hidden"
  end
end
