require "test_helper"

class Admin::PaymentsHelperTest < ActionView::TestCase
  test "format_money renders USD with $ symbol and delimiters" do
    assert_equal "$1,234", format_money(123_400, "usd")
    assert_equal "$0",     format_money(0,        "usd")
    assert_equal "$0",     format_money(nil,      "usd")
  end

  test "format_money renders EUR/GBP with their symbols" do
    assert_equal "€500",  format_money(50_000,  "eur")
    assert_equal "£2,500", format_money(250_000, "gbp")
  end

  test "format_money falls back to uppercased currency code for unknown currencies" do
    assert_equal "BRL 1,234", format_money(123_400, "brl")
  end

  test "currency_symbol is case-insensitive" do
    assert_equal "$", currency_symbol("USD")
    assert_equal "$", currency_symbol("usd")
  end

  test "payment_amount uses payment's own currency" do
    customer = create(:customer)
    payment  = create(:payment, customer: customer, amount_cents: 7_700, currency: "eur")
    assert_equal "€77", payment_amount(payment)
  end

  test "payment_product_label returns subscription's display_product when linked" do
    customer = create(:customer)
    sub      = create(:subscription, customer: customer, product_code: "alpha")
    payment  = create(:payment, customer: customer, subscription: sub)

    assert_equal "alpha", payment_product_label(payment)
  end

  test "payment_product_label returns 'one-off' span when no subscription" do
    customer = create(:customer)
    payment  = create(:payment, customer: customer, subscription: nil)

    html = payment_product_label(payment)
    assert_match "one-off", html
    assert_match "italic",  html
  end
end
