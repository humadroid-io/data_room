FactoryBot.define do
  factory :snapshot do
    subscription
    snapshot_date       { Date.current.beginning_of_month }
    mrr_cents           { 10_000 }
    status              { :active }
    captured_attributes { {} }
  end
end
