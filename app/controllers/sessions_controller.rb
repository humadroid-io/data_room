class SessionsController < ApplicationController
  layout "auth"

  def new
    redirect_to root_path if investor_signed_in?
  end

  def create
    code     = params[:access_code].to_s.strip
    investor = Investor.usable.find_by(access_code: code) if code.present?

    if investor
      investor.update_column(:last_login_at, Time.current)
      sign_in_investor(investor)
      redirect_to root_path, notice: "Welcome, #{investor.name}."
    else
      flash.now[:alert] = "Invalid access code, or your access has expired."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out_investor
    redirect_to login_path, notice: "Signed out."
  end
end
