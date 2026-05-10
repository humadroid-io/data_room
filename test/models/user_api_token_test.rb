require "test_helper"

class UserApiTokenTest < ActiveSupport::TestCase
  test "regenerate_api_token! sets a fresh prefixed token" do
    user = create(:user)
    user.regenerate_api_token!
    assert_match(/\Adr_/, user.api_token)
  end

  test "regenerating produces a new value each time" do
    user = create(:user)
    user.regenerate_api_token!
    first = user.api_token
    user.regenerate_api_token!
    refute_equal first, user.api_token
  end

  test "authenticate_by_api_token returns the user for a valid token" do
    user = create(:user)
    user.regenerate_api_token!
    assert_equal user, User.authenticate_by_api_token(user.api_token)
  end

  test "authenticate_by_api_token returns nil for blank token" do
    assert_nil User.authenticate_by_api_token(nil)
    assert_nil User.authenticate_by_api_token("")
  end

  test "authenticate_by_api_token returns nil for unknown token" do
    assert_nil User.authenticate_by_api_token("dr_unknown")
  end
end
