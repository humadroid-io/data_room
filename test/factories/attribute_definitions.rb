FactoryBot.define do
  factory :attribute_definition do
    resource_type { "Customer" }
    sequence(:key) { |n| "attr_#{n}" }
    label         { "Attribute" }
    data_type     { :string }
    sort_order    { 0 }

    factory :single_select_attribute do
      data_type { :single_select }
      after(:build) do |defn|
        defn.attribute_options.build(value: "a", label: "A", color: "info",    sort_order: 0)
        defn.attribute_options.build(value: "b", label: "B", color: "warning", sort_order: 1)
      end
    end

    factory :multi_select_attribute do
      data_type { :multi_select }
      after(:build) do |defn|
        defn.attribute_options.build(value: "x", label: "X", sort_order: 0)
        defn.attribute_options.build(value: "y", label: "Y", sort_order: 1)
      end
    end

    factory :captured_attribute do
      data_type           { :single_select }
      capture_on_snapshot { true }
      after(:build) do |defn|
        defn.attribute_options.build(value: "stage1", label: "Stage 1", sort_order: 0)
      end
    end
  end

  factory :attribute_option do
    attribute_definition
    sequence(:value) { |n| "opt_#{n}" }
    label            { "Option" }
    sort_order       { 0 }
  end
end
