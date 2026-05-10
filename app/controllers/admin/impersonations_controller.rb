class Admin::ImpersonationsController < Admin::BaseController
  def create
    investor = Investor.find(params[:investor_id])
    sign_in_investor(investor)
    redirect_to safe_return_path, notice: "Now viewing the site as #{investor.name}."
  end

  def destroy
    sign_out_investor
    redirect_to admin_investors_path, notice: "Stopped viewing as investor."
  end

  private

  def safe_return_path
    raw = params[:return_to].to_s
    raw.start_with?("/") && !raw.start_with?("//") && !raw.start_with?("/admin") ? raw : root_path
  end
end
