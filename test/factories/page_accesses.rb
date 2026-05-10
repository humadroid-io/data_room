FactoryBot.define do
  factory :page_access do
    association :page, factory: :private_page
    investor
  end
end
