class StripePaymentImporter
  def self.run
    new.run
  end

  def run
    return 0 unless StripeConfig.configured?

    count = 0
    Stripe::Invoice.list(status: "paid", limit: 100, expand: [ "data.subscription" ])
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

  def resolve_subscription(invoice)
    sub = invoice.respond_to?(:subscription) ? invoice.subscription : nil
    sub_id = sub.is_a?(String) ? sub : sub&.id
    sub_id && Subscription.find_by(stripe_subscription_id: sub_id)
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
