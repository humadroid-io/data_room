FactoryBot.define do
  factory :event do
    sequence(:title) { |n| "Event #{n}" }
    occurred_on      { Date.current }
    kind             { :other }
    description      { nil }
  end
end
