require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 390, 844 ]

  include FactoryBot::Syntax::Methods

  private

  def sign_in_investor(investor)
    visit login_path
    fill_in "access_code", with: investor.access_code
    click_button "Continue"
  end

  def sign_in_admin(admin)
    visit admin_login_path
    fill_in "email", with: admin.email
    fill_in "password", with: "password123"
    click_button "Sign in"
  end

  def open_mobile_menu
    find("summary", text: "Menu").click
  end
end
