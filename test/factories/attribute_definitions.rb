FactoryBot.define do
  factory :attribute_definition do
    resource_type { "Customer" }
    sequence(:key) { |n| "attr_#{n}" }
    label         { "Attribute" }
    data_type     { :string }
    sort_order    { 0 }

    factory :single_select_attribute do
      data_type { :single_select }
      options do
        [
          { "value" => "a", "label" => "A", "color" => "info" },
          { "value" => "b", "label" => "B", "color" => "warning" }
        ]
      end
    end

    factory :multi_select_attribute do
      data_type { :multi_select }
      options do
        [
          { "value" => "x", "label" => "X" },
          { "value" => "y", "label" => "Y" }
        ]
      end
    end

    factory :captured_attribute do
      data_type           { :single_select }
      capture_on_snapshot { true }
      options do
        [ { "value" => "stage1", "label" => "Stage 1" } ]
      end
    end
  end
end
