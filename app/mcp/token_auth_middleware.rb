class TokenAuthMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    token = extract_token(env)
    user  = User.authenticate_by_api_token(token)

    return unauthorized unless user
    return forbidden    unless user.admin?

    env["data_room.current_admin"] = user
    @app.call(env)
  end

  private

  def extract_token(env)
    header = env["HTTP_AUTHORIZATION"].to_s
    return $1 if header =~ /\ABearer\s+(.+)\z/i
    nil
  end

  def unauthorized
    [
      401,
      { "Content-Type" => "application/json", "WWW-Authenticate" => 'Bearer realm="data-room-mcp"' },
      [ { error: "unauthorized", detail: "Provide a valid Bearer token." }.to_json ]
    ]
  end

  def forbidden
    [ 403, { "Content-Type" => "application/json" }, [ { error: "forbidden" }.to_json ] ]
  end
end
