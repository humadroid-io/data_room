class Admin::DashboardsController < Admin::BaseController
  def show
    @page_count       = Page.count
    @live_pages       = Page.live.count
    @investor_count   = Investor.usable.count
    @customer_count   = Customer.count
    @active_mrr_cents = Subscription.active_now.sum(:mrr_cents)
    @recent_views     = PageView.order(viewed_at: :desc).includes(:investor, :page).limit(10)

    @stripe = {
      configured:   StripeConfig.configured?,
      mode:         StripeConfig.customer_import_mode,
      last_sync_at: Rails.cache.read("stripe:last_sync_at"),
      summary:      Rails.cache.read("stripe:last_sync_summary") || {}
    }
  end

  def regenerate_token
    current_admin.regenerate_api_token!
    redirect_to admin_root_path, notice: "MCP token regenerated. Update any agents that used the old token."
  end
end
