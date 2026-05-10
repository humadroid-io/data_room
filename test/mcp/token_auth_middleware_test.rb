require "test_helper"

class TokenAuthMiddlewareTest < ActiveSupport::TestCase
  setup do
    @inner_app = ->(env) { [ 200, { "Content-Type" => "text/plain" }, [ "ok" ] ] }
    @middleware = TokenAuthMiddleware.new(@inner_app)
  end

  test "401 with no Authorization header" do
    status, headers, _ = @middleware.call({})
    assert_equal 401, status
    assert_match(/Bearer/, headers["WWW-Authenticate"])
  end

  test "401 when token unknown" do
    status, _, _ = @middleware.call("HTTP_AUTHORIZATION" => "Bearer nope")
    assert_equal 401, status
  end

  test "401 when not Bearer scheme" do
    user = create(:user)
    user.regenerate_api_token!
    status, _, _ = @middleware.call("HTTP_AUTHORIZATION" => "Basic #{user.api_token}")
    assert_equal 401, status
  end

  test "200 and forwards env when Bearer matches an admin user" do
    user = create(:user, role: :admin)
    user.regenerate_api_token!
    env = { "HTTP_AUTHORIZATION" => "Bearer #{user.api_token}" }
    status, _, _ = @middleware.call(env)
    assert_equal 200, status
    assert_equal user, env["data_room.current_admin"]
  end

  test "403 when token belongs to a non-admin (viewer) user" do
    user = create(:user, role: :viewer)
    user.regenerate_api_token!
    status, _, _ = @middleware.call("HTTP_AUTHORIZATION" => "Bearer #{user.api_token}")
    assert_equal 403, status
  end
end
