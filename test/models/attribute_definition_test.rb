require "test_helper"

class AttributeDefinitionTest < ActiveSupport::TestCase
  should validate_presence_of(:resource_type)
  should validate_presence_of(:label)
  should validate_presence_of(:key)
  should define_enum_for(:data_type).with_values(
    string: 0, text: 1, integer: 2, decimal: 3, date: 4,
    boolean: 5, single_select: 6, multi_select: 7
  )

  test "rejects invalid key format" do
    defn = build(:attribute_definition, key: "BadKey")
    assert_not defn.valid?
    assert defn.errors[:key].any?
  end

  test "key must be unique within resource type" do
    create(:attribute_definition, resource_type: "Customer", key: "stage")
    dup = build(:attribute_definition, resource_type: "Customer", key: "stage")
    assert_not dup.valid?
    assert dup.errors[:key].any?
  end

  test "key may repeat across resource types" do
    create(:attribute_definition, resource_type: "Customer",     key: "stage")
    other = build(:attribute_definition, resource_type: "Subscription", key: "stage")
    assert other.valid?
  end

  test "for_resource scope returns ordered defs for class" do
    a = create(:attribute_definition, resource_type: "Customer", key: "a", sort_order: 2)
    b = create(:attribute_definition, resource_type: "Customer", key: "b", sort_order: 1)
    create(:attribute_definition, resource_type: "Subscription",  key: "c")

    assert_equal [ b, a ], AttributeDefinition.for_resource(Customer).to_a
  end

  test "captured scope returns only attrs flagged for snapshot" do
    captured = create(:captured_attribute, key: "captured_one")
    create(:attribute_definition, key: "ignored")
    assert_includes AttributeDefinition.captured, captured
    assert_equal 1, AttributeDefinition.captured.count
  end
end
