FactoryBot.define do
  factory :subscription do
    customer
    sequence(:stripe_subscription_id) { |n| "sub_#{n}" }
    sequence(:stripe_customer_id)     { |n| "cus_#{n}" }
    sequence(:stripe_price_id)        { |n| "price_#{n}" }
    product_code { "alpha" }
    mrr_cents    { 10_000 }
    currency     { "usd" }
    status       { :active }
    started_at   { 1.month.ago }
  end
end
