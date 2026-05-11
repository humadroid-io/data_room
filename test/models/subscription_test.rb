require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  subject { build(:subscription) }

  should belong_to(:customer)
  should have_many(:snapshots).dependent(:destroy)
  should have_many(:payments).dependent(:nullify)
  should validate_presence_of(:stripe_subscription_id)
  should validate_uniqueness_of(:stripe_subscription_id)
  should validate_presence_of(:stripe_customer_id)

  should define_enum_for(:status).with_values(
    active: 0, past_due: 1, canceled: 2, paused: 3, trialing: 4, incomplete: 5
  )

  test "active_now scope includes active and trialing" do
    a = create(:subscription, status: :active)
    t = create(:subscription, status: :trialing)
    create(:subscription, status: :canceled)

    assert_includes Subscription.active_now, a
    assert_includes Subscription.active_now, t
    assert_equal 2, Subscription.active_now.count
  end

  test "for_product scope filters by product code" do
    a = create(:subscription, product_code: "alpha")
    b = create(:subscription, product_code: "beta")

    assert_equal [ a ], Subscription.for_product("alpha").to_a
    assert_equal [ b ], Subscription.for_product("beta").to_a
  end

  test "display_product returns product_code when present" do
    sub = build(:subscription, product_code: "alpha", stripe_price_id: "price_123")
    assert_equal "alpha", sub.display_product
  end

  test "display_product falls back to stripe_price_id when product_code is blank" do
    sub = build(:subscription, product_code: nil, stripe_price_id: "price_123")
    assert_equal "price_123", sub.display_product
  end

  test "display_product returns dash when both are blank" do
    sub = build(:subscription, product_code: nil, stripe_price_id: nil)
    assert_equal "—", sub.display_product
  end

  # --- USD normalization --------------------------------------------------

  test "computes mrr_cents_usd from EUR on save" do
    sub = create(:subscription, mrr_cents: 8_500, currency: "eur")
    assert_equal 10_000, sub.mrr_cents_usd  # 8500 / 0.85 = 10000
  end

  test "computes mrr_cents_usd from PLN on save" do
    sub = create(:subscription, mrr_cents: 36_000, currency: "pln")
    assert_equal 10_000, sub.mrr_cents_usd  # 36000 / 3.6 = 10000
  end

  test "passes USD through unchanged" do
    sub = create(:subscription, mrr_cents: 10_000, currency: "usd")
    assert_equal 10_000, sub.mrr_cents_usd
  end

  test "recomputes mrr_cents_usd when currency changes" do
    sub = create(:subscription, mrr_cents: 36_000, currency: "pln")
    assert_equal 10_000, sub.mrr_cents_usd
    sub.update!(currency: "usd")
    assert_equal 36_000, sub.mrr_cents_usd
  end

  # --- effective_mrr_cents_usd --------------------------------------------

  test "effective_mrr falls back to nominal when no payments exist" do
    sub = create(:subscription, mrr_cents: 10_000, currency: "usd", interval_months: 1)
    assert_equal 10_000, sub.effective_mrr_cents_usd
  end

  test "effective_mrr uses latest payment for monthly subs (reflects discounts)" do
    # Nominal $100/mo but customer paid $90 (10% off coupon).
    sub = create(:subscription, mrr_cents: 10_000, currency: "usd", interval_months: 1)
    create(:payment, customer: sub.customer, subscription: sub,
                     amount_cents: 9_000, currency: "usd", paid_at: 1.day.ago)
    assert_equal 9_000, sub.effective_mrr_cents_usd
  end

  test "effective_mrr amortizes latest payment for annual subs" do
    # List $1200/yr ($100/mo nominal). Customer paid $1080/yr → $90/mo effective.
    sub = create(:subscription, mrr_cents: 10_000, currency: "usd", interval_months: 12)
    create(:payment, customer: sub.customer, subscription: sub,
                     amount_cents: 108_000, currency: "usd", paid_at: 1.month.ago)
    assert_equal 9_000, sub.effective_mrr_cents_usd
  end

  test "effective_mrr respects as_of by only considering earlier payments" do
    sub = create(:subscription, mrr_cents: 10_000, currency: "usd", interval_months: 1)
    create(:payment, customer: sub.customer, subscription: sub,
                     amount_cents: 9_000, currency: "usd", paid_at: Date.new(2026, 3, 5))
    create(:payment, customer: sub.customer, subscription: sub,
                     amount_cents: 8_500, currency: "usd", paid_at: Date.new(2026, 5, 5))

    assert_equal 9_000, sub.effective_mrr_cents_usd(as_of: Date.new(2026, 4, 1))
    assert_equal 8_500, sub.effective_mrr_cents_usd(as_of: Date.new(2026, 6, 1))
  end
end
