require "test_helper"

class Admin::SubscriptionShowTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "GET show renders the subscription with linked payments" do
    customer = create(:customer, name: "Acme")
    sub = create(:subscription, customer: customer, product_code: "alpha", mrr_cents: 50_000)
    create(:payment, customer: customer, subscription: sub, amount_cents: 50_000, paid_at: 1.day.ago)

    get admin_subscription_path(sub)
    assert_response :success
    body = response.body
    assert_match "alpha",  body
    assert_match "Acme",   body
    assert_match "$500",   body
  end

  test "GET show requires admin sign-in" do
    sub = create(:subscription)
    delete admin_logout_path
    get admin_subscription_path(sub)
    assert_redirected_to admin_login_path
  end
end
