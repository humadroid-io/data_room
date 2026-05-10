require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/login renders" do
    get admin_login_path
    assert_response :success
  end

  test "POST signs in admin" do
    admin = create(:user)
    post admin_login_path, params: { email: admin.email, password: "password123" }
    assert_redirected_to admin_root_path
  end

  test "POST with bad password renders new" do
    admin = create(:user)
    post admin_login_path, params: { email: admin.email, password: "wrong" }
    assert_response :unprocessable_entity
  end

  test "DELETE signs out admin" do
    sign_in_admin
    delete admin_logout_path
    assert_redirected_to admin_login_path
  end
end
