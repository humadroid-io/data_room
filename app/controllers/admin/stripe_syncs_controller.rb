class Admin::StripeSyncsController < Admin::BaseController
  def create
    unless StripeConfig.configured?
      redirect_to admin_root_path,
                  alert: "Stripe API key is not set. Add it to encrypted credentials or STRIPE_API_KEY env var."
      return
    end

    result = StripeSyncJob.perform_now
    redirect_to admin_root_path,
                notice: "Stripe sync ran. Imported #{result[:customers]} customers, " \
                        "synced #{result[:subscriptions]} subscriptions."
  rescue Stripe::AuthenticationError => e
    redirect_to admin_root_path, alert: "Stripe rejected the API key: #{e.message}"
  rescue Stripe::StripeError => e
    redirect_to admin_root_path, alert: "Stripe error: #{e.message}"
  end
end
