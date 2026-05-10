require "test_helper"
require "ostruct"

class StripeSyncJobTest < ActiveJob::TestCase
  setup do
    @customer = create(:customer, stripe_customer_id: "cus_abc")
    StripeConfig.stubs(:configured?).returns(true)
    StripeConfig.stubs(:product_code_for).with("price_x").returns("alpha")
    StripeConfig.stubs(:product_code_for).with(nil).returns(nil)
    StripeCustomerImporter.stubs(:run).returns(0)
    StripePaymentImporter.stubs(:run).returns(0)
  end

  test "raises when API key is not configured" do
    StripeConfig.unstub(:configured?)
    StripeConfig.stubs(:configured?).returns(false)
    assert_raises(StripeSyncJob::StripeApiKeyMissing) { StripeSyncJob.perform_now }
  end

  test "delegates customer import to StripeCustomerImporter" do
    StripeCustomerImporter.unstub(:run)
    StripeCustomerImporter.expects(:run).once.returns(0)
    empty_list = mock("list")
    empty_list.stubs(:auto_paging_each)
    Stripe::Subscription.stubs(:list).returns(empty_list)
    ActionCable.server.stubs(:broadcast)

    StripeSyncJob.perform_now
  end

  test "creates a Subscription from a Stripe payload" do
    list = mock("list")
    list.stubs(:auto_paging_each).multiple_yields(stripe_payload("sub_123", "cus_abc"))
    Stripe::Subscription.stubs(:list).returns(list)
    ActionCable.server.stubs(:broadcast)

    assert_difference -> { Subscription.count }, 1 do
      StripeSyncJob.perform_now
    end

    sub = Subscription.find_by!(stripe_subscription_id: "sub_123")
    assert_equal @customer, sub.customer
    assert_equal "price_x", sub.stripe_price_id
    assert_equal "alpha",   sub.product_code
    assert_equal 9_900,     sub.mrr_cents
    assert_equal "active",  sub.status
  end

  test "leaves product_code nil when the price isn't mapped" do
    StripeConfig.stubs(:product_code_for).with("price_unmapped").returns(nil)
    list = mock("list")
    list.stubs(:auto_paging_each).multiple_yields(stripe_payload("sub_999", "cus_abc", price_id: "price_unmapped"))
    Stripe::Subscription.stubs(:list).returns(list)
    ActionCable.server.stubs(:broadcast)

    StripeSyncJob.perform_now
    sub = Subscription.find_by!(stripe_subscription_id: "sub_999")
    assert_nil sub.product_code
    assert_equal "price_unmapped", sub.stripe_price_id
    assert_equal "price_unmapped", sub.display_product
  end

  test "skips orphan subscription without matching customer" do
    list = mock("list")
    list.stubs(:auto_paging_each).multiple_yields(stripe_payload("sub_orphan", "cus_unknown"))
    Stripe::Subscription.stubs(:list).returns(list)
    ActionCable.server.stubs(:broadcast)

    assert_no_difference -> { Subscription.count } do
      StripeSyncJob.perform_now
    end
  end

  test "broadcasts on completion" do
    list = mock("list")
    list.stubs(:auto_paging_each)
    Stripe::Subscription.stubs(:list).returns(list)

    ActionCable.server.expects(:broadcast).with("data_room", has_entry(event: "stripe_synced"))
    StripeSyncJob.perform_now
  end

  test "writes last-sync timestamp and summary to cache" do
    list = mock("list")
    list.stubs(:auto_paging_each).multiple_yields(stripe_payload("sub_123", "cus_abc"))
    Stripe::Subscription.stubs(:list).returns(list)
    ActionCable.server.stubs(:broadcast)

    written = {}
    Rails.cache.stubs(:write).with { |key, value, _| written[key] = value; true }

    StripeSyncJob.perform_now

    assert_kind_of Time, written["stripe:last_sync_at"]
    assert_equal({ customers: 0, subscriptions: 1, payments: 0 }, written["stripe:last_sync_summary"])
  end

  private

  def stripe_payload(sub_id, customer_id, price_id: "price_x")
    price = OpenStruct.new(id: price_id, unit_amount: 9_900,
                           recurring: OpenStruct.new(interval: "month"))
    item  = OpenStruct.new(price: price, quantity: 1)
    items = OpenStruct.new(data: [ item ])
    OpenStruct.new(
      id: sub_id, customer: customer_id, status: "active",
      currency: "usd", start_date: 1.month.ago.to_i,
      canceled_at: nil, pause_collection: nil, items: items
    )
  end
end
