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
end
