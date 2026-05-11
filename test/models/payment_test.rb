require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  subject { build(:payment) }

  should belong_to(:customer)
  should belong_to(:subscription).optional
  should validate_presence_of(:stripe_invoice_id)
  should validate_uniqueness_of(:stripe_invoice_id)
  should validate_presence_of(:paid_at)

  test "amount converts cents to dollars" do
    payment = build(:payment, amount_cents: 12_345)
    assert_equal 123.45, payment.amount
  end

  test "by_paid_at orders most-recent first" do
    customer = create(:customer)
    older = create(:payment, customer: customer, paid_at: 2.months.ago)
    newer = create(:payment, customer: customer, paid_at: 1.day.ago)
    assert_equal [ newer, older ], Payment.by_paid_at.to_a
  end

  # --- backfill_subscriptions! --------------------------------------------

  test "backfill_subscriptions! links orphan payment when customer has exactly one matching sub" do
    customer = create(:customer)
    sub      = create(:subscription, customer: customer,
                                      started_at: 2.months.ago, canceled_at: nil)
    payment  = create(:payment, customer: customer, subscription: nil, paid_at: 1.month.ago)

    assert_equal 1, Payment.backfill_subscriptions!
    assert_equal sub, payment.reload.subscription
  end

  test "backfill_subscriptions! does not link when customer has multiple matching subs" do
    customer = create(:customer)
    create(:subscription, customer: customer, started_at: 2.months.ago, canceled_at: nil)
    create(:subscription, customer: customer, started_at: 2.months.ago, canceled_at: nil)
    payment = create(:payment, customer: customer, subscription: nil, paid_at: 1.month.ago)

    assert_equal 0, Payment.backfill_subscriptions!
    assert_nil payment.reload.subscription
  end

  test "backfill_subscriptions! ignores subs that weren't active at paid_at" do
    customer = create(:customer)
    create(:subscription, customer: customer, started_at: 6.months.ago, canceled_at: 3.months.ago)
    create(:subscription, customer: customer, started_at: 1.day.ago,    canceled_at: nil)
    payment = create(:payment, customer: customer, subscription: nil, paid_at: 2.months.ago)

    assert_equal 0, Payment.backfill_subscriptions!
    assert_nil payment.reload.subscription
  end

  test "backfill_subscriptions! leaves already-linked payments alone" do
    customer = create(:customer)
    sub      = create(:subscription, customer: customer)
    payment  = create(:payment, customer: customer, subscription: sub)

    assert_equal 0, Payment.backfill_subscriptions!
    assert_equal sub, payment.reload.subscription
  end
end
