require "test_helper"
require "ostruct"

class StripeCustomerImporterTest < ActiveSupport::TestCase
  test "none mode does nothing" do
    Stripe::Customer.expects(:list).never
    Stripe::Invoice.expects(:list).never

    assert_no_difference -> { Customer.count } do
      assert_equal 0, StripeCustomerImporter.run(mode: :none)
    end
  end

  test "all mode upserts every Stripe customer" do
    list = mock("list")
    list.stubs(:auto_paging_each).multiple_yields(
      stripe_customer("cus_1", name: "Acme Inc"),
      stripe_customer("cus_2", name: nil, email: "ops@example.com"),
      stripe_customer("cus_3", name: nil, email: nil)
    )
    Stripe::Customer.stubs(:list).returns(list)

    assert_difference -> { Customer.count }, 3 do
      assert_equal 3, StripeCustomerImporter.run(mode: :all)
    end

    assert_equal "Acme Inc",                 Customer.find_by(stripe_customer_id: "cus_1").name
    assert_equal "ops@example.com",          Customer.find_by(stripe_customer_id: "cus_2").name
    assert_equal "Stripe Customer cus_3",    Customer.find_by(stripe_customer_id: "cus_3").name
  end

  test "all mode is idempotent — does not duplicate existing customers" do
    create(:customer, stripe_customer_id: "cus_existing", name: "Already Here")

    list = mock("list")
    list.stubs(:auto_paging_each).multiple_yields(stripe_customer("cus_existing", name: "Renamed"))
    Stripe::Customer.stubs(:list).returns(list)

    assert_no_difference -> { Customer.count } do
      assert_equal 0, StripeCustomerImporter.run(mode: :all)
    end
    # Existing rows are not overwritten — admin edits win.
    assert_equal "Already Here", Customer.find_by(stripe_customer_id: "cus_existing").name
  end

  test "paying mode imports only customers with a paid invoice" do
    invoices = mock("invoices")
    invoices.stubs(:auto_paging_each).multiple_yields(
      OpenStruct.new(customer: "cus_paid_1"),
      OpenStruct.new(customer: "cus_paid_2"),
      OpenStruct.new(customer: "cus_paid_1") # dup → still one customer
    )
    Stripe::Invoice.stubs(:list).with(status: "paid", limit: 100).returns(invoices)

    Stripe::Customer.stubs(:retrieve).with("cus_paid_1").returns(stripe_customer("cus_paid_1", name: "Paid 1"))
    Stripe::Customer.stubs(:retrieve).with("cus_paid_2").returns(stripe_customer("cus_paid_2", name: "Paid 2"))

    assert_difference -> { Customer.count }, 2 do
      StripeCustomerImporter.run(mode: :paying)
    end
    assert Customer.exists?(stripe_customer_id: "cus_paid_1")
    assert Customer.exists?(stripe_customer_id: "cus_paid_2")
  end

  test "paying mode skips customers already imported (no extra Stripe call)" do
    create(:customer, stripe_customer_id: "cus_existing", name: "Local")

    invoices = mock("invoices")
    invoices.stubs(:auto_paging_each).multiple_yields(OpenStruct.new(customer: "cus_existing"))
    Stripe::Invoice.stubs(:list).returns(invoices)

    Stripe::Customer.expects(:retrieve).never

    assert_no_difference -> { Customer.count } do
      StripeCustomerImporter.run(mode: :paying)
    end
  end

  test "raises on unknown mode" do
    assert_raises(ArgumentError) { StripeCustomerImporter.run(mode: :wat) }
  end

  private

  def stripe_customer(id, name: nil, email: nil)
    OpenStruct.new(id: id, name: name, email: email)
  end
end
