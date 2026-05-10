require "test_helper"

class Admin::ImpersonationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "POST signs in admin as a chosen investor" do
    investor = create(:investor)
    post admin_impersonations_path, params: { investor_id: investor.id }
    assert_redirected_to root_path
  end

  test "POST honors safe return_to under root" do
    investor = create(:investor)
    create(:landing_page)
    create(:section_page, slug: "company")

    post admin_impersonations_path, params: { investor_id: investor.id, return_to: "/company" }
    assert_redirected_to "/company"
  end

  test "POST rejects return_to that points into admin" do
    investor = create(:investor)
    post admin_impersonations_path, params: { investor_id: investor.id, return_to: "/admin/customers" }
    assert_redirected_to root_path
  end

  test "POST rejects scheme-relative return_to" do
    investor = create(:investor)
    post admin_impersonations_path, params: { investor_id: investor.id, return_to: "//evil.example.com" }
    assert_redirected_to root_path
  end

  test "DELETE clears investor session and returns to admin" do
    investor = create(:investor)
    post admin_impersonations_path, params: { investor_id: investor.id }
    delete admin_impersonation_path(investor)
    assert_redirected_to admin_investors_path
  end

  test "requires admin sign-in" do
    delete admin_logout_path
    investor = create(:investor)
    post admin_impersonations_path, params: { investor_id: investor.id }
    assert_redirected_to admin_login_path
  end
end
