require "test_helper"

class AttributeOptionTest < ActiveSupport::TestCase
  subject { build(:attribute_option) }

  should belong_to(:attribute_definition)
  should validate_presence_of(:value)
  should validate_presence_of(:label)
  should validate_uniqueness_of(:value).scoped_to(:attribute_definition_id)
  should validate_inclusion_of(:color).in_array(AttributeOption::COLORS).allow_blank

  test "rejects values that aren't snake/kebab case" do
    opt = build(:attribute_option, value: "Bad Value!")
    assert_not opt.valid?
    assert opt.errors[:value].any?
  end

  test "value uniqueness is scoped per definition" do
    a = create(:attribute_definition, key: "alpha")
    b = create(:attribute_definition, key: "beta")
    create(:attribute_option, attribute_definition: a, value: "shared")
    dup   = build(:attribute_option, attribute_definition: a, value: "shared")
    other = build(:attribute_option, attribute_definition: b, value: "shared")

    assert_not dup.valid?
    assert     other.valid?
  end
end
