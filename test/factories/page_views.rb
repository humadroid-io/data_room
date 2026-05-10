FactoryBot.define do
  factory :page_view do
    investor
    page
    viewed_at { Time.current }
  end
end
