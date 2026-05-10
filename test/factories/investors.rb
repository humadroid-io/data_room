FactoryBot.define do
  factory :investor do
    sequence(:email) { |n| "investor#{n}@example.com" }
    sequence(:access_code) { |n| "code_#{SecureRandom.hex(6)}_#{n}" }
    name             { "Investor" }
    fund_name        { "VC" }
    watermark_label  { "Investor — VC" }
    active           { true }
  end
end
