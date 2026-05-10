require "test_helper"
require "ostruct"

class StripePaymentImporterTest < ActiveSupport::TestCase
  setup do
    StripeConfig.stubs(:configured?).returns(true)
    @customer = create(:customer, stripe_customer_id: "cus_abc")
  end

  test "returns 0 and skips Stripe when not configured" do
    StripeConfig.unstub(:configured?)
    StripeConfig.stubs(:configured?).returns(false)
    Stripe::Invoice.expects(:list).never

    assert_equal 0, StripePaymentImporter.run
  end

  test "imports a paid invoice and links it to the customer" do
    invoices = mock("list")
    invoices.stubs(:auto_paging_each).multiple_yields(
      stripe_invoice("in_1", "cus_abc", amount_paid: 8_500, paid_at: 1.day.ago)
    )
    Stripe::Invoice.stubs(:list).returns(invoices)

    assert_difference -> { Payment.count }, 1 do
      assert_equal 1, StripePaymentImporter.run
    end

    payment = Payment.find_by!(stripe_invoice_id: "in_1")
    assert_equal @customer, payment.customer
    assert_equal 8_500, payment.amount_cents
  end

  test "links payment to a known subscription when present" do
    sub = create(:subscription, customer: @customer, stripe_subscription_id: "sub_77")
    invoices = mock("list")
    invoices.stubs(:auto_paging_each).multiple_yields(
      stripe_invoice("in_2", "cus_abc", subscription_id: "sub_77")
    )
    Stripe::Invoice.stubs(:list).returns(invoices)

    StripePaymentImporter.run
    assert_equal sub, Payment.find_by!(stripe_invoice_id: "in_2").subscription
  end

  test "leaves subscription nil when invoice has no subscription" do
    invoices = mock("list")
    invoices.stubs(:auto_paging_each).multiple_yields(
      stripe_invoice("in_3", "cus_abc", subscription_id: nil)
    )
    Stripe::Invoice.stubs(:list).returns(invoices)

    StripePaymentImporter.run
    assert_nil Payment.find_by!(stripe_invoice_id: "in_3").subscription
  end

  test "skips orphan invoices for unknown customers" do
    invoices = mock("list")
    invoices.stubs(:auto_paging_each).multiple_yields(
      stripe_invoice("in_orphan", "cus_unknown")
    )
    Stripe::Invoice.stubs(:list).returns(invoices)

    assert_no_difference -> { Payment.count } do
      assert_equal 0, StripePaymentImporter.run
    end
  end

  test "tolerates invoices that lack the legacy `charge` field" do
    # Mirrors Stripe's newer API where Invoice#charge was removed.
    invoice = OpenStruct.new(
      id: "in_no_charge", customer: "cus_abc", amount_paid: 1_200,
      currency: "usd",
      status_transitions: OpenStruct.new(paid_at: 1.hour.ago.to_i)
      # no :charge, no :payments
    )
    invoices = mock("list")
    invoices.stubs(:auto_paging_each).multiple_yields(invoice)
    Stripe::Invoice.stubs(:list).returns(invoices)

    assert_difference -> { Payment.count }, 1 do
      StripePaymentImporter.run
    end
    assert_nil Payment.find_by!(stripe_invoice_id: "in_no_charge").stripe_charge_id
  end

  test "extracts charge id from the new payments[] shape when available" do
    nested_payment = OpenStruct.new(payment: OpenStruct.new(charge: "ch_new_shape"))
    payments_list  = OpenStruct.new(data: [ nested_payment ])
    invoice = OpenStruct.new(
      id: "in_new_shape", customer: "cus_abc", amount_paid: 5_000,
      currency: "usd", payments: payments_list,
      status_transitions: OpenStruct.new(paid_at: 1.hour.ago.to_i)
    )
    invoices = mock("list")
    invoices.stubs(:auto_paging_each).multiple_yields(invoice)
    Stripe::Invoice.stubs(:list).returns(invoices)

    StripePaymentImporter.run
    assert_equal "ch_new_shape", Payment.find_by!(stripe_invoice_id: "in_new_shape").stripe_charge_id
  end

  test "is idempotent — re-importing the same invoice updates rather than duplicates" do
    create(:payment, customer: @customer, stripe_invoice_id: "in_existing", amount_cents: 100)

    invoices = mock("list")
    invoices.stubs(:auto_paging_each).multiple_yields(
      stripe_invoice("in_existing", "cus_abc", amount_paid: 200)
    )
    Stripe::Invoice.stubs(:list).returns(invoices)

    assert_no_difference -> { Payment.count } do
      assert_equal 0, StripePaymentImporter.run # 0 NEW rows
    end
    assert_equal 200, Payment.find_by!(stripe_invoice_id: "in_existing").amount_cents
  end

  private

  def stripe_invoice(id, customer_id, amount_paid: 9_900, subscription_id: nil, paid_at: 1.hour.ago)
    sub_obj = subscription_id && OpenStruct.new(id: subscription_id)
    OpenStruct.new(
      id: id,
      customer: customer_id,
      subscription: sub_obj,
      charge: "ch_#{id}",
      amount_paid: amount_paid,
      currency: "usd",
      status_transitions: OpenStruct.new(paid_at: paid_at.to_i)
    )
  end
end
