class StripePaymentImporter
  def self.run
    new.run
  end

  def run
    return 0 unless StripeConfig.configured?

    count = 0
    Stripe::Invoice.list(status: "paid", limit: 100, expand: [ "data.subscription", "data.lines.data" ])
                   .auto_paging_each do |invoice|
      count += 1 if upsert(invoice)
    end
    count
  end

  private

  def upsert(invoice)
    customer = Customer.find_by(stripe_customer_id: invoice.customer)
    unless customer
      Rails.logger.warn("StripePaymentImporter: orphan invoice #{invoice.id} (no Customer with stripe_customer_id #{invoice.customer})")
      return false
    end

    payment = Payment.find_or_initialize_by(stripe_invoice_id: invoice.id)
    payment.assign_attributes(
      customer:         customer,
      subscription:     resolve_subscription(invoice),
      stripe_charge_id: charge_id_for(invoice),
      amount_cents:     invoice.amount_paid,
      currency:         invoice.currency,
      paid_at:          paid_at_for(invoice)
    )
    new_record = payment.new_record?
    payment.save!
    new_record
  end

  # Walks every place Stripe might expose the originating subscription:
  #   1. invoice.subscription (older API, top-level reference)
  #   2. invoice.lines.data[*].subscription (newer API; line-level)
  #   3. invoice.subscription_details.subscription (current API on some shapes)
  # Returns the first matching local Subscription, or nil.
  def resolve_subscription(invoice)
    candidate_ids = []

    if invoice.respond_to?(:subscription)
      candidate_ids << id_from(invoice.subscription)
    end

    if invoice.respond_to?(:subscription_details)
      details = invoice.subscription_details
      candidate_ids << id_from(details.respond_to?(:subscription) ? details.subscription : nil)
    end

    if invoice.respond_to?(:lines)
      lines = invoice.lines.respond_to?(:data) ? invoice.lines.data : invoice.lines
      Array(lines).each do |line|
        candidate_ids << id_from(line.respond_to?(:subscription) ? line.subscription : nil)
      end
    end

    candidate_ids.compact.uniq.each do |stripe_sub_id|
      found = Subscription.find_by(stripe_subscription_id: stripe_sub_id)
      return found if found
    end
    nil
  end

  def id_from(reference)
    return nil if reference.nil?
    reference.is_a?(String) ? reference : (reference.respond_to?(:id) ? reference.id : nil)
  end

  def paid_at_for(invoice)
    transitions = invoice.respond_to?(:status_transitions) ? invoice.status_transitions : nil
    paid_unix   = transitions.respond_to?(:paid_at) ? transitions.paid_at : nil
    paid_unix ? Time.at(paid_unix) : Time.current
  end

  # Stripe API <2024 exposed `invoice.charge` directly. Newer API versions
  # removed it in favour of `invoice.payments` (a list of payment intents
  # each containing a charge id). Try both shapes; returning nil is fine —
  # this column is informational and nothing in the app depends on it.
  def charge_id_for(invoice)
    return invoice.charge if invoice.respond_to?(:charge) && invoice.charge

    payments = invoice.respond_to?(:payments) ? invoice.payments : nil
    first = payments.respond_to?(:data) ? payments.data&.first : nil
    return nil unless first

    payment_obj = first.respond_to?(:payment) ? first.payment : first
    payment_obj.respond_to?(:charge) ? payment_obj.charge : nil
  end
end
