require "application_system_test_case"

class MobileNavigationTest < ApplicationSystemTestCase
  test "investor can navigate to nested pages from the mobile menu" do
    create(:landing_page)
    section = create(:section_page, slug: "company", title: "Company")
    child = create(:child_page, parent_page: section, slug: "team", title: "Team")
    investor = create(:investor)

    sign_in_investor(investor)

    open_mobile_menu
    within_mobile_data_room_nav do
      click_link section.title
    end

    assert_current_path section.path

    open_mobile_menu
    within_mobile_data_room_nav do
      click_link child.title
    end

    assert_current_path child.path
    assert_text child.title
  end

  test "admin can navigate from the mobile menu" do
    admin = create(:user)

    sign_in_admin(admin)

    open_mobile_menu
    within "ul[aria-label='Mobile admin navigation']" do
      click_link "Pages"
    end

    assert_current_path admin_pages_path
    assert_selector "h1", text: "Pages"
  end

  private

  def within_mobile_data_room_nav(&block)
    within "ul[aria-label='Mobile data room navigation']", &block
  end
end
