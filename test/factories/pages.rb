FactoryBot.define do
  factory :page do
    sequence(:title) { |n| "Page #{n}" }
    sequence(:slug)  { |n| "page-#{n}" }
    visibility       { :public }
    sort_order       { 0 }

    factory :landing_page do
      title { "Welcome" }
      slug  { "" }
      parent { nil }
    end

    factory :section_page do
      parent { nil }
    end

    factory :child_page do
      transient { parent_page { nil } }
      parent { parent_page || create(:section_page) }
    end

    factory :draft_page do
      visibility { :draft }
    end

    factory :private_page do
      visibility { :private }
    end
  end
end
