class StripeCustomerImporter
  MODES = StripeConfig::MODES

  def self.run(mode: StripeConfig.customer_import_mode)
    new(mode: mode).run
  end

  attr_reader :mode

  def initialize(mode:)
    @mode = mode.to_sym
    raise ArgumentError, "Unknown mode #{@mode.inspect}" unless MODES.include?(@mode)
  end

  def run
    case mode
    when :none   then 0
    when :all    then import_all
    when :paying then import_paying
    end
  end

  private

  def import_all
    count = 0
    Stripe::Customer.list(limit: 100).auto_paging_each do |customer|
      count += 1 if upsert(customer)
    end
    count
  end

  def import_paying
    paying_ids = Set.new
    Stripe::Invoice.list(status: "paid", limit: 100).auto_paging_each do |invoice|
      paying_ids << invoice.customer if invoice.customer
    end

    count = 0
    paying_ids.each do |stripe_id|
      next if Customer.exists?(stripe_customer_id: stripe_id)
      stripe_customer = Stripe::Customer.retrieve(stripe_id)
      count += 1 if upsert(stripe_customer)
    end
    count
  end

  def upsert(stripe_customer)
    customer = Customer.find_or_initialize_by(stripe_customer_id: stripe_customer.id)
    return false unless customer.new_record?

    customer.name = customer_name_for(stripe_customer)
    customer.save!
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("StripeCustomerImporter: #{stripe_customer.id} skipped — #{e.message}")
    false
  end

  def customer_name_for(stripe_customer)
    stripe_customer.name.presence ||
      stripe_customer.email.presence ||
      "Stripe Customer #{stripe_customer.id}"
  end
end
