class Admin::SubscriptionsController < Admin::BaseController
  before_action :set_subscription, only: %i[show edit update destroy]

  def index
    @subscriptions = Subscription.includes(:customer).order(created_at: :desc)
  end

  def show
    @payments      = @subscription.payments.order(paid_at: :desc).limit(20)
    @total_paid    = @subscription.payments.sum(:amount_cents_usd)
    @snapshot_runs = @subscription.snapshots.order(snapshot_date: :desc).limit(12)
  end

  def new
    @subscription = Subscription.new(
      customer_id: params[:customer_id],
      mrr_cents:   0,
      status:      :active,
      started_at:  Time.current
    )
  end

  def edit; end

  def create
    @subscription = Subscription.new(subscription_params)
    if @subscription.save
      redirect_to admin_customer_path(@subscription.customer), notice: "Subscription added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @subscription.update(subscription_params)
      redirect_to admin_customer_path(@subscription.customer), notice: "Subscription updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    customer = @subscription.customer
    @subscription.destroy
    redirect_to admin_customer_path(customer), notice: "Subscription removed."
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(
      :customer_id, :stripe_customer_id, :stripe_subscription_id,
      :stripe_price_id, :product_code, :mrr_cents, :currency, :status,
      :started_at, :canceled_at, :paused_at
    )
  end
end
