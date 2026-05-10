FactoryBot.define do
  factory :customer do
    sequence(:name) { |n| "Customer #{n}" }
    custom_attributes { {} }

    factory :churned_customer do
      churned_on            { 1.month.ago.to_date }
      churn_reason_category { :other }
      churn_reason_notes    { nil }
    end
  end
end
