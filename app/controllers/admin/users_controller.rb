class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[show edit update destroy regenerate_api_token]

  def index
    @users = User.order(:name)
  end

  def show; end

  def new
    @user = User.new(role: :admin)
  end

  def edit; end

  def create
    @user = User.new(user_params_for_create)
    if @user.save
      redirect_to admin_users_path, notice: "User created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if would_remove_last_admin?(@user, params: user_params_for_update)
      @user.errors.add(:base, "Cannot demote or deactivate the last admin.")
      render :edit, status: :unprocessable_entity and return
    end

    if @user.update(user_params_for_update)
      redirect_to admin_users_path, notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_admin
      redirect_to admin_users_path, alert: "You can't delete your own account." and return
    end
    if @user.admin? && User.admin.count <= 1
      redirect_to admin_users_path, alert: "Can't delete the last admin." and return
    end

    @user.destroy
    redirect_to admin_users_path, notice: "User deleted."
  end

  def regenerate_api_token
    @user.regenerate_api_token!
    redirect_to edit_admin_user_path(@user),
                notice: "MCP token rotated for #{@user.email}."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params_for_create
    params.require(:user).permit(:name, :email, :role, :password, :password_confirmation)
  end

  def user_params_for_update
    attrs = params.require(:user).permit(:name, :email, :role, :password, :password_confirmation)
    if attrs[:password].blank?
      attrs.delete(:password)
      attrs.delete(:password_confirmation)
    end
    attrs
  end

  def would_remove_last_admin?(user, params:)
    return false unless user.admin?
    return false if params[:role].blank? || params[:role].to_s == "admin"
    User.admin.where.not(id: user.id).none?
  end
end
