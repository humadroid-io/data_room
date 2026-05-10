require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  should have_many(:subscriptions).dependent(:destroy)
  should have_many(:payments).dependent(:destroy)
  should validate_presence_of(:name)

  test "missing required custom attribute fails validation" do
    create(:attribute_definition, resource_type: "Customer", key: "stage",
           data_type: :string, required: true, label: "Stage")

    customer = build(:customer, custom_attributes: {})
    assert_not customer.valid?
    assert_match(/Stage is required/, customer.errors[:custom_attributes].join)
  end

  test "rejects invalid single_select value" do
    create(:single_select_attribute, key: "stage", label: "Stage")

    customer = build(:customer, custom_attributes: { "stage" => "nope" })
    assert_not customer.valid?
    assert_match(/Stage has invalid value/, customer.errors[:custom_attributes].join)
  end

  test "accepts valid single_select value" do
    create(:single_select_attribute, key: "stage", label: "Stage")

    customer = build(:customer, custom_attributes: { "stage" => "a" })
    assert customer.valid?
  end

  test "rejects multi_select with invalid items" do
    create(:multi_select_attribute, key: "tags", label: "Tags")
    customer = build(:customer, custom_attributes: { "tags" => [ "x", "bad" ] })
    assert_not customer.valid?
    assert_match(/Tags has invalid values/, customer.errors[:custom_attributes].join)
  end

  test "rejects integer attribute that is not an integer" do
    create(:attribute_definition, resource_type: "Customer", key: "size",
           data_type: :integer, label: "Size")
    customer = build(:customer, custom_attributes: { "size" => "abc" })
    assert_not customer.valid?
  end

  test "rejects invalid date attribute" do
    create(:attribute_definition, resource_type: "Customer", key: "audit",
           data_type: :date, label: "Audit")
    customer = build(:customer, custom_attributes: { "audit" => "not-a-date" })
    assert_not customer.valid?
  end

  test "captured_attributes_for_snapshot only returns captured keys" do
    create(:captured_attribute, key: "stage", options: [ { "value" => "s1", "label" => "S1" } ])
    create(:attribute_definition, resource_type: "Customer", key: "industry",
           data_type: :string, label: "Industry")

    customer = create(:customer, custom_attributes: { "stage" => "s1", "industry" => "saas" })
    assert_equal({ "stage" => "s1" }, customer.captured_attributes_for_snapshot)
  end

  test "custom_attribute_label returns option label for select" do
    create(:single_select_attribute, key: "stage", label: "Stage")
    customer = create(:customer, custom_attributes: { "stage" => "a" })
    assert_equal "A", customer.custom_attribute_label("stage")
  end

  test "with_custom_attribute scope filters by JSON value" do
    create(:single_select_attribute, key: "stage", label: "Stage")
    matching = create(:customer, custom_attributes: { "stage" => "a" })
    create(:customer, custom_attributes: { "stage" => "b" })

    assert_equal [ matching ], Customer.with_custom_attribute("stage", "a").to_a
  end

  test "with_custom_attribute_containing scope filters multi_select arrays" do
    create(:multi_select_attribute, key: "tags", label: "Tags")
    matching = create(:customer, custom_attributes: { "tags" => [ "x", "y" ] })
    create(:customer, custom_attributes: { "tags" => [ "y" ] })

    assert_equal [ matching ], Customer.with_custom_attribute_containing("tags", "x").to_a
  end

  test "scope rejects sql injection via key argument" do
    assert_raises(ArgumentError) do
      Customer.with_custom_attribute("'; DROP TABLE customers; --", "x").to_a
    end
  end

  # --- churn ---------------------------------------------------------------

  test "active scope returns customers without a churn date" do
    active  = create(:customer)
    churned = create(:churned_customer)

    assert_includes     Customer.active, active
    assert_not_includes Customer.active, churned
    assert_includes     Customer.churned, churned
    assert_not_includes Customer.churned, active
  end

  test "churned predicate is true when churned_on is set" do
    assert_not build(:customer).churned?
    assert build(:churned_customer).churned?
  end

  test "rejects a churn reason without a churn date" do
    customer = build(:customer, churned_on: nil, churn_reason_category: :price)
    assert_not customer.valid?
    assert_match(/churned on/i, customer.errors.full_messages.join)
  end

  test "rejects churn reason notes without a churn date" do
    customer = build(:customer, churned_on: nil, churn_reason_notes: "left for cheaper")
    assert_not customer.valid?
  end

  test "accepts a churn date with no reason recorded" do
    customer = build(:customer, churned_on: 1.day.ago.to_date)
    assert customer.valid?
  end

  test "churned_in_period filters by date range" do
    create(:churned_customer, churned_on: Date.new(2025, 12, 1))
    inside = create(:churned_customer, churned_on: Date.new(2026, 3, 1))
    create(:churned_customer, churned_on: Date.new(2026, 7, 1))

    assert_equal [ inside ], Customer.churned_in_period(Date.new(2026, 1, 1), Date.new(2026, 6, 30)).to_a
  end

  test "churn_reason_category enum maps to integers" do
    customer = create(:churned_customer, churn_reason_category: :price)
    assert_equal "price", customer.churn_reason_category
    assert customer.churn_reason_category_price?
  end
end
