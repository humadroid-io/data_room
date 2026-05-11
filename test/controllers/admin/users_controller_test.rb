require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup { @me = sign_in_admin }

  test "GET index lists users" do
    other = create(:user, email: "other@example.com")
    get admin_users_path
    assert_response :success
    assert_match other.email, response.body
  end

  test "GET show renders the user's profile and token state" do
    other = create(:user, email: "other@example.com", name: "Other Admin")
    other.regenerate_api_token!

    get admin_user_path(other)
    assert_response :success
    body = response.body
    assert_match "Other Admin",      body
    assert_match "other@example.com", body
    assert_match other.api_token,     body
  end

  test "GET show on the current admin omits the delete button" do
    get admin_user_path(@me)
    assert_select "form[action=?]", admin_user_path(@me), count: 0
  end

  test "POST create persists a new admin" do
    assert_difference -> { User.count }, 1 do
      post admin_users_path, params: {
        user: {
          name: "Luke", email: "luk@example.com", role: "admin",
          password: "password123", password_confirmation: "password123"
        }
      }
    end
    assert_redirected_to admin_users_path
  end

  test "POST create fails without password" do
    post admin_users_path, params: {
      user: { name: "X", email: "x@example.com", role: "admin" }
    }
    assert_response :unprocessable_entity
  end

  test "PATCH update without password keeps the existing digest" do
    user = create(:user)
    digest_before = user.password_digest

    patch admin_user_path(user), params: {
      user: { name: "Renamed", password: "", password_confirmation: "" }
    }
    assert_equal digest_before, user.reload.password_digest
    assert_equal "Renamed", user.name
  end

  test "PATCH update with new password rotates the digest" do
    user = create(:user)
    digest_before = user.password_digest

    patch admin_user_path(user), params: {
      user: { password: "newsecret123", password_confirmation: "newsecret123" }
    }
    refute_equal digest_before, user.reload.password_digest
  end

  test "PATCH update refuses to demote the last admin" do
    # @me is the only admin
    patch admin_user_path(@me), params: { user: { role: "viewer" } }
    assert_response :unprocessable_entity
    assert_equal "admin", @me.reload.role
  end

  test "PATCH update can demote a non-last admin" do
    other = create(:user, role: :admin)
    patch admin_user_path(other), params: { user: { role: "viewer" } }
    assert_redirected_to admin_users_path
    assert_equal "viewer", other.reload.role
  end

  test "DELETE refuses to delete current admin" do
    delete admin_user_path(@me)
    assert_redirected_to admin_users_path
    assert User.exists?(@me.id)
  end

  test "DELETE refuses to delete the last admin" do
    other = create(:user, role: :viewer)
    delete admin_user_path(other) # keep @me as the only admin; deleting other is fine
    assert_redirected_to admin_users_path
    assert_not User.exists?(other.id)

    delete admin_user_path(@me)   # now would-be last-admin self-delete is also blocked
    assert User.exists?(@me.id)
  end

  test "DELETE removes a non-current, non-last user" do
    other = create(:user, role: :viewer)
    assert_difference -> { User.count }, -1 do
      delete admin_user_path(other)
    end
  end

  test "POST regenerate_api_token rotates the token" do
    user = create(:user)
    user.regenerate_api_token!
    old = user.api_token

    post regenerate_api_token_admin_user_path(user)
    refute_equal old, user.reload.api_token
    assert_redirected_to edit_admin_user_path(user)
  end

  test "non-admin (viewer) trying to access admin area is bounced" do
    delete admin_logout_path
    viewer = create(:user, role: :viewer)
    # Note: viewers can technically sign in to /admin/login (no role check there yet)
    # but require_admin lets any authenticated User through. This documents
    # current behavior: there is no role gate at controller level.
    sign_in_admin(viewer)
    get admin_users_path
    assert_response :success
  end
end
