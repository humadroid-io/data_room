class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :current_investor, :investor_signed_in?,
                :current_admin,    :admin_signed_in?,
                :viewing_as_admin?

  private

  def current_investor
    @current_investor ||= authenticated_investor
  end

  def authenticated_investor
    return nil unless cookies.encrypted[:investor_id]
    Investor.usable.find_by(id: cookies.encrypted[:investor_id])
  end

  def investor_signed_in?
    current_investor.present?
  end

  def sign_in_investor(investor)
    cookies.encrypted[:investor_id] = {
      value:    investor.id,
      httponly: true,
      same_site: :lax,
      expires:  30.days.from_now
    }
  end

  def sign_out_investor
    cookies.delete(:investor_id)
    @current_investor = nil
  end

  def require_investor
    return if investor_signed_in?
    redirect_to login_path, alert: "Please sign in."
  end

  def require_viewer
    return if investor_signed_in? || admin_signed_in?
    redirect_to login_path, alert: "Please sign in."
  end

  def viewing_as_admin?
    admin_signed_in? && !investor_signed_in?
  end

  def current_admin
    @current_admin ||= authenticated_admin
  end

  def authenticated_admin
    return nil unless cookies.encrypted[:admin_user_id]
    User.find_by(id: cookies.encrypted[:admin_user_id])
  end

  def admin_signed_in?
    current_admin.present?
  end

  def sign_in_admin(user)
    cookies.encrypted[:admin_user_id] = {
      value:    user.id,
      httponly: true,
      same_site: :lax,
      expires:  30.days.from_now
    }
  end

  def sign_out_admin
    cookies.delete(:admin_user_id)
    @current_admin = nil
  end

  def require_admin
    return if admin_signed_in?
    redirect_to admin_login_path, alert: "Admin sign-in required."
  end
end
