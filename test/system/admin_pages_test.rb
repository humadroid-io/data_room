require "application_system_test_case"

class AdminPagesTest < ApplicationSystemTestCase
  test "admin can create a page and visit its public version" do
    admin = create(:user)

    sign_in_admin(admin)

    open_mobile_menu
    within "ul[aria-label='Mobile admin navigation']" do
      click_link "Pages"
    end
    click_link "New page"

    fill_in "page_title", with: "Investor Update"
    fill_in "page_slug", with: "investor-update"
    fill_in "page_tldr", with: "Q2 investor update."
    click_button "Create page"

    assert_text "Page created."
    assert_text "Investor Update"
    assert_text "/investor-update"

    click_link "Public version"

    assert_current_path "/investor-update"
    assert_text "Investor Update"
    assert_text "Q2 investor update."
  end
end
