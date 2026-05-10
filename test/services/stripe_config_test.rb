require "test_helper"

class StripeConfigTest < ActiveSupport::TestCase
  test "customer_import_mode returns the symbol from the YAML" do
    StripeConfig.stubs(:env_config).returns({ "customer_import" => "all", "products" => {} })
    assert_equal :all, StripeConfig.customer_import_mode
  end

  test "customer_import_mode defaults to :none when missing" do
    StripeConfig.stubs(:env_config).returns({ "products" => {} })
    assert_equal :none, StripeConfig.customer_import_mode
  end

  test "customer_import_mode raises on an unknown value" do
    StripeConfig.stubs(:env_config).returns({ "customer_import" => "wat" })
    assert_raises(RuntimeError) { StripeConfig.customer_import_mode }
  end

  test "products returns the new-shape map" do
    StripeConfig.stubs(:env_config).returns({
      "customer_import" => "all",
      "products"        => { "price_a" => "alpha", "price_b" => "beta" }
    })
    assert_equal({ "price_a" => "alpha", "price_b" => "beta" }, StripeConfig.products)
  end

  test "products returns an empty hash when no products are configured" do
    StripeConfig.stubs(:env_config).returns({ "customer_import" => "all" })
    assert_equal({}, StripeConfig.products)
  end

  test "products handles legacy flat-hash shape" do
    StripeConfig.stubs(:env_config).returns({ "price_x" => "alpha" })
    assert_equal({ "price_x" => "alpha" }, StripeConfig.products)
  end

  test "product_code_for returns the mapped value or nil" do
    StripeConfig.stubs(:env_config).returns({ "products" => { "price_known" => "alpha" } })
    assert_equal "alpha", StripeConfig.product_code_for("price_known")
    assert_nil StripeConfig.product_code_for("price_other")
    assert_nil StripeConfig.product_code_for(nil)
    assert_nil StripeConfig.product_code_for("")
  end

  test "configured? is true when an api key is present" do
    StripeConfig.stubs(:api_key).returns("sk_test_xxx")
    assert StripeConfig.configured?
  end

  test "configured? is false when api key is blank" do
    StripeConfig.stubs(:api_key).returns(nil)
    assert_not StripeConfig.configured?
  end
end
