class Admin::PaymentsController < Admin::BaseController
  def index
    @payments     = Payment.includes(:customer, subscription: []).order(paid_at: :desc).limit(100)
    @total_count  = Payment.count
    @total_amount = Payment.sum(:amount_cents_usd)
    @last_paid_at = Payment.maximum(:paid_at)
  end

  def show
    @payment = Payment.find(params[:id])
  end
end
