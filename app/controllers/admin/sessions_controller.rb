class Admin::SessionsController < ApplicationController
  layout "auth"

  def new
    redirect_to admin_root_path if admin_signed_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      sign_in_admin(user)
      redirect_to admin_root_path, notice: "Welcome, #{user.name}."
    else
      flash.now[:alert] = "Wrong email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out_admin
    redirect_to admin_login_path, notice: "Signed out."
  end
end
