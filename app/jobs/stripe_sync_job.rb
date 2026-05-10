class StripeSyncJob < ApplicationJob
  queue_as :default

  class StripeApiKeyMissing < StandardError; end

  def perform
    raise StripeApiKeyMissing, "Set credentials.stripe.api_key or STRIPE_API_KEY env var" unless StripeConfig.configured?

    customers_imported = StripeCustomerImporter.run

    subs_synced = 0
    Stripe::Subscription.list(
      status: "all", limit: 100,
      expand: [ "data.items.data.price" ]
    ).auto_paging_each do |stripe_sub|
      subs_synced += 1 if sync_subscription(stripe_sub)
    end

    payments_imported = StripePaymentImporter.run

    summary = { customers: customers_imported, subscriptions: subs_synced, payments: payments_imported }
    Rails.cache.write("stripe:last_sync_at", Time.current, expires_in: 1.year)
    Rails.cache.write("stripe:last_sync_summary", summary, expires_in: 1.year)

    ActionCable.server.broadcast("data_room", { event: "stripe_synced", at: Time.current.iso8601 })

    summary
  end

  private

  def sync_subscription(s)
    sub = Subscription.find_or_initialize_by(stripe_subscription_id: s.id)

    customer = sub.customer || Customer.find_by(stripe_customer_id: s.customer)
    unless customer
      Rails.logger.warn("StripeSyncJob: orphan subscription #{s.id} (no Customer with stripe_customer_id #{s.customer})")
      return false
    end

    price_id = s.items.data.first&.price&.id

    sub.assign_attributes(
      customer:           customer,
      stripe_customer_id: s.customer,
      mrr_cents:          extract_mrr_cents(s),
      currency:           s.currency,
      status:             map_status(s.status),
      stripe_price_id:    price_id,
      product_code:       StripeConfig.product_code_for(price_id),
      started_at:         s.start_date && Time.at(s.start_date),
      canceled_at:        s.canceled_at ? Time.at(s.canceled_at) : nil,
      paused_at:          s.pause_collection ? Time.current : nil,
      last_synced_at:     Time.current
    )
    sub.save!
    true
  end

  def extract_mrr_cents(s)
    s.items.data.sum do |item|
      price = item.price
      qty   = item.quantity || 1
      case price.recurring&.interval
      when "month" then price.unit_amount * qty
      when "year"  then (price.unit_amount * qty) / 12
      else 0
      end
    end
  end

  def map_status(stripe_status)
    {
      "active"             => :active,
      "past_due"           => :past_due,
      "canceled"           => :canceled,
      "unpaid"             => :past_due,
      "paused"             => :paused,
      "trialing"           => :trialing,
      "incomplete"         => :incomplete,
      "incomplete_expired" => :canceled
    }.fetch(stripe_status, :incomplete)
  end
end
