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

  test "usd_money formats from cents to USD dollars with $ symbol" do
    assert_equal "$1,234", usd_money(123_400)
    assert_equal "$0",     usd_money(0)
    assert_equal "$0",     usd_money(nil)
  end

  test "payment_amount always returns USD regardless of native currency" do
    customer = create(:customer)
    # 7700 EUR cents → 7700 / 0.85 ≈ 9059 USD cents → $90
    eur_payment = create(:payment, customer: customer, amount_cents: 7_700, currency: "eur")
    assert_equal "$90", payment_amount(eur_payment)

    usd_payment = create(:payment, customer: customer, amount_cents: 5_000, currency: "usd")
    assert_equal "$50", payment_amount(usd_payment)
  end

  test "payment_native_amount shows the original currency" do
    customer = create(:customer)
    payment  = create(:payment, customer: customer, amount_cents: 7_700, currency: "eur")
    assert_equal "€77", payment_native_amount(payment)
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
