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
end
