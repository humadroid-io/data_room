require "test_helper"

class Admin::CustomersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "GET index" do
    create(:customer)
    get admin_customers_path
    assert_response :success
  end

  test "POST create with custom_attributes for select type" do
    create(:single_select_attribute, key: "stage", label: "Stage")

    assert_difference -> { Customer.count }, 1 do
      post admin_customers_path, params: {
        customer: {
          name: "Acme",
          custom_attributes: { stage: "a" }
        }
      }
    end
    assert_equal "a", Customer.last.custom_attribute("stage")
  end

  test "POST create coerces multi_select to array" do
    create(:multi_select_attribute, key: "tags", label: "Tags")

    post admin_customers_path, params: {
      customer: { name: "Acme", custom_attributes: { tags: [ "x", "y" ] } }
    }
    assert_equal [ "x", "y" ], Customer.last.custom_attribute("tags")
  end

  test "POST create rejects invalid select" do
    create(:single_select_attribute, key: "stage", label: "Stage")
    post admin_customers_path, params: {
      customer: { name: "Acme", custom_attributes: { stage: "bogus" } }
    }
    assert_response :unprocessable_entity
  end

  test "DELETE destroys customer" do
    c = create(:customer)
    assert_difference -> { Customer.count }, -1 do
      delete admin_customer_path(c)
    end
  end
end
