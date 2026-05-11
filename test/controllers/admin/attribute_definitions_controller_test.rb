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

  test "POST create persists nested attribute_options for a select type" do
    assert_difference -> { AttributeDefinition.count } => 1,
                      -> { AttributeOption.count }     => 2 do
      post admin_attribute_definitions_path, params: {
        attribute_definition: {
          resource_type: "Customer",
          key:           "stage",
          label:         "Stage",
          data_type:     :single_select,
          attribute_options_attributes: {
            "0" => { value: "open",   label: "Open",   color: "info",    sort_order: 0 },
            "1" => { value: "closed", label: "Closed", color: "success", sort_order: 1 }
          }
        }
      }
    end

    assert_redirected_to admin_attribute_definitions_path
    defn = AttributeDefinition.find_by!(key: "stage")
    assert_equal %w[open closed], defn.attribute_options.map(&:value)
  end

  test "PATCH update can remove an option via _destroy" do
    defn = create(:single_select_attribute, key: "stage")
    target = defn.attribute_options.first

    patch admin_attribute_definition_path(defn), params: {
      attribute_definition: {
        attribute_options_attributes: {
          "0" => { id: target.id, _destroy: "1" }
        }
      }
    }

    assert_redirected_to admin_attribute_definitions_path
    assert_nil AttributeOption.find_by(id: target.id)
  end

  test "POST create surfaces validation errors for blank option fields" do
    assert_no_difference [ "AttributeDefinition.count", "AttributeOption.count" ] do
      post admin_attribute_definitions_path, params: {
        attribute_definition: {
          resource_type: "Customer",
          key:           "stage",
          label:         "Stage",
          data_type:     :single_select,
          attribute_options_attributes: {
            "0" => { value: "open", label: "" }
          }
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "requires admin sign-in" do
    defn = create(:attribute_definition)
    delete admin_logout_path
    get admin_attribute_definition_path(defn)
    assert_redirected_to admin_login_path
  end
end
