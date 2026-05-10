FactoryBot.define do
  factory :page_redirect do
    page
    sequence(:old_path) { |n| "/old-path-#{n}" }
  end
end
