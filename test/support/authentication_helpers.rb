module AuthenticationHelpers
  def sign_in_investor(investor = nil)
    investor ||= create(:investor)
    post login_path, params: { access_code: investor.access_code }
    investor
  end

  def sign_in_admin(user = nil)
    user ||= create(:user)
    post admin_login_path, params: { email: user.email, password: "password123" }
    user
  end
end
