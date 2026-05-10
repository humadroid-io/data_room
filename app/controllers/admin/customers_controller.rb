class Admin::CustomersController < Admin::BaseController
  before_action :set_customer, only: %i[show edit update destroy]

  def index
    @customers = Customer.order(:name)
  end

  def show
    @recent_payments      = @customer.payments.order(paid_at: :desc).limit(20)
    @total_paid_cents     = @customer.payments.sum(:amount_cents)
    @total_payments_count = @customer.payments.count
  end

  def new
    @customer = Customer.new
  end

  def edit; end

  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      redirect_to admin_customer_path(@customer), notice: "Customer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @customer.update(customer_params)
      redirect_to admin_customer_path(@customer), notice: "Customer updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to admin_customers_path, notice: "Customer deleted."
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    raw = params.require(:customer).permit(
      :name, :anonymized_label, :stripe_customer_id, :notes, :reference_call_ok,
      :churned_on, :churn_reason_category, :churn_reason_notes
    )
    raw[:custom_attributes] = extract_custom_attributes
    raw
  end

  def extract_custom_attributes
    submitted = params.dig(:customer, :custom_attributes) || {}
    submitted = submitted.to_unsafe_h if submitted.respond_to?(:to_unsafe_h)
    result = {}
    AttributeDefinition.for_resource(Customer).each do |defn|
      raw = submitted[defn.key] || submitted[defn.key.to_sym]
      next if raw.nil?
      value = case defn.data_type
              when "multi_select" then Array(raw).compact_blank
              when "boolean"      then ActiveModel::Type::Boolean.new.cast(raw)
              else raw
              end
      next if value.is_a?(String) && value.strip.empty?
      next if value.is_a?(Array)  && value.empty?
      result[defn.key] = value
    end
    result
  end
end
