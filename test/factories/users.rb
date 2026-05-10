FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "admin#{n}@example.com" }
    name             { "Admin" }
    password         { "password123" }
    role             { :admin }
  end
end
