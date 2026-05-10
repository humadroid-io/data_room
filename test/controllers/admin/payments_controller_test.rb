require "test_helper"

class Admin::PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "GET /admin/payments renders empty state with no payments" do
    get admin_payments_path
    assert_response :success
    assert_match "No payments imported yet", response.body
  end

  test "GET /admin/payments lists most-recent payments first" do
    customer = create(:customer, name: "Acme Co")
    create(:payment, customer: customer, paid_at: 3.days.ago, amount_cents: 5_000)
    create(:payment, customer: customer, paid_at: 1.day.ago,  amount_cents: 9_900)

    get admin_payments_path
    assert_response :success
    body = response.body
    assert_match "Acme Co", body

    # Newer payment ($99) should appear before the older one ($50) in the rendered HTML.
    newer_pos = body.index("$99")
    older_pos = body.index("$50")
    assert newer_pos && older_pos, "expected both payment amounts in the response"
    assert_operator newer_pos, :<, older_pos
  end

  test "GET /admin/payments shows totals" do
    customer = create(:customer)
    create(:payment, customer: customer, amount_cents: 1_000)
    create(:payment, customer: customer, amount_cents: 2_500)

    get admin_payments_path
    body = response.body
    assert_match "$35", body                 # total received: $35
    assert_match ">2<",  body                # total count: 2 (in the count card)
  end

  test "GET /admin/payments caps the list at 100 most-recent" do
    customer = create(:customer)
    105.times { |i| create(:payment, customer: customer, paid_at: (i + 1).hours.ago) }

    get admin_payments_path
    assert_select "table tbody tr", count: 100
    assert_match "Showing 100 most recent of 105 total", response.body
  end

  test "GET /admin/payments labels one-off payments" do
    customer = create(:customer)
    create(:payment, customer: customer, subscription: nil)

    get admin_payments_path
    assert_match "one-off", response.body
  end

  test "GET /admin/payments shows display_product for sub-linked payments" do
    customer = create(:customer)
    sub      = create(:subscription, customer: customer, product_code: "alpha")
    create(:payment, customer: customer, subscription: sub)

    get admin_payments_path
    assert_match "alpha", response.body
  end

  test "requires admin sign-in" do
    delete admin_logout_path
    get admin_payments_path
    assert_redirected_to admin_login_path
  end
end
