require "test_helper"

class Admin::AttributeDefinitionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "GET index lists definitions grouped by resource type" do
    create(:attribute_definition, resource_type: "Customer", key: "alpha")
    get admin_attribute_definitions_path
    assert_response :success
    assert_match "Customer", response.body
    assert_match "alpha",    response.body
  end

  test "GET show renders schema and usage counts for a Customer attribute" do
    defn = create(:single_select_attribute, key: "stage", label: "Stage")
    create(:customer, custom_attributes: { "stage" => "a" })
    create(:customer, custom_attributes: {})

    get admin_attribute_definition_path(defn)
    assert_response :success
    body = response.body
    assert_match "Stage",          body
    assert_match "single_select",  body
    # Usage card present (1 of 2 customers have a value)
    assert_match "1",              body
  end

  test "GET show works for non-Customer resource types without usage stats" do
    defn = create(:attribute_definition, resource_type: "Subscription", key: "k")
    get admin_attribute_definition_path(defn)
    assert_response :success
  end

  test "requires admin sign-in" do
    defn = create(:attribute_definition)
    delete admin_logout_path
    get admin_attribute_definition_path(defn)
    assert_redirected_to admin_login_path
  end
end
