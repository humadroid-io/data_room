require "test_helper"

class CurrencyConverterTest < ActiveSupport::TestCase
  test "USD passes through unchanged" do
    assert_equal 10_000, CurrencyConverter.to_usd_cents(10_000, "usd")
    assert_equal 10_000, CurrencyConverter.to_usd_cents(10_000, "USD")
  end

  test "EUR converts at 1 EUR = 1/0.85 USD" do
    # 8500 EUR cents = 85.00 EUR → 100.00 USD → 10000 USD cents
    assert_equal 10_000, CurrencyConverter.to_usd_cents(8_500, "eur")
  end

  test "PLN converts at 1 PLN = 1/3.6 USD" do
    # 36000 PLN smallest unit = 360 PLN → 100 USD → 10000 USD cents
    assert_equal 10_000, CurrencyConverter.to_usd_cents(36_000, "pln")
  end

  test "currency code is case-insensitive" do
    assert_equal CurrencyConverter.to_usd_cents(10_000, "eur"),
                 CurrencyConverter.to_usd_cents(10_000, "EUR")
  end

  test "raises on unknown currency" do
    assert_raises(CurrencyConverter::UnknownCurrency) do
      CurrencyConverter.to_usd_cents(1_000, "btc")
    end
  end

  test "zero and nil input short-circuit to 0" do
    assert_equal 0, CurrencyConverter.to_usd_cents(0,   "eur")
    assert_equal 0, CurrencyConverter.to_usd_cents(nil, "pln")
  end

  test "rounds half to nearest integer cent" do
    # 100 PLN cents → 100/3.6 ≈ 27.78 → rounds to 28
    assert_equal 28, CurrencyConverter.to_usd_cents(100, "pln")
  end
end
