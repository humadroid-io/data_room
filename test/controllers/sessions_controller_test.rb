require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /login renders" do
    get login_path
    assert_response :success
  end

  test "GET /login prefills the access code from query" do
    get login_path(code: "abc-123")
    assert_select "input[name='access_code'][value='abc-123']"
  end

  test "POST /login with a valid access code signs in and redirects" do
    investor = create(:investor)
    post login_path, params: { access_code: investor.access_code }
    assert_redirected_to root_path
  end

  test "POST /login updates last_login_at" do
    investor = create(:investor, last_login_at: nil)
    post login_path, params: { access_code: investor.access_code }
    assert_not_nil investor.reload.last_login_at
  end

  test "POST /login with unknown code renders new" do
    create(:investor)
    post login_path, params: { access_code: "nope-12345" }
    assert_response :unprocessable_entity
  end

  test "POST /login with blank code renders new" do
    post login_path, params: { access_code: "   " }
    assert_response :unprocessable_entity
  end

  test "POST /login rejects expired investor" do
    investor = create(:investor, access_expires_at: 1.day.ago)
    post login_path, params: { access_code: investor.access_code }
    assert_response :unprocessable_entity
  end

  test "POST /login rejects inactive investor" do
    investor = create(:investor, active: false)
    post login_path, params: { access_code: investor.access_code }
    assert_response :unprocessable_entity
  end

  test "DELETE /logout signs out and redirects to login" do
    sign_in_investor
    delete logout_path
    assert_redirected_to login_path
  end
end
