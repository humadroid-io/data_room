FactoryBot.define do
  factory :payment do
    customer
    subscription { nil }
    sequence(:stripe_invoice_id) { |n| "in_#{n}" }
    amount_cents { 9_900 }
    currency     { "usd" }
    paid_at      { Time.current }
  end
end
