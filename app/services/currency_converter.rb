# Converts Stripe money values into USD using fixed FX rates.
#
# Stripe amounts are in the smallest unit of the native currency:
#   EUR / USD → cents (1/100); PLN → grosz (1/100).
# Conversion is unit-preserving — input cents, output cents.
#
# Rates live here as a single source of truth. If they need to change,
# edit them and run `rake currency:reconvert` to backfill existing rows.
module CurrencyConverter
  module_function

  # 1 USD = 3.6 PLN  →  1 PLN = 1/3.6 USD
  # 1 USD = 0.85 EUR →  1 EUR = 1/0.85 USD
  RATES_TO_USD = {
    "usd" => 1.0,
    "eur" => 1.0 / 0.85,
    "pln" => 1.0 / 3.6
  }.freeze

  class UnknownCurrency < ArgumentError; end

  def to_usd_cents(cents, currency)
    return 0 if cents.nil? || cents.zero?
    rate = RATES_TO_USD[currency.to_s.downcase] or
      raise UnknownCurrency, "Unknown currency: #{currency.inspect}. Add it to CurrencyConverter::RATES_TO_USD."
    (cents.to_f * rate).round
  end

  def supported_currencies
    RATES_TO_USD.keys
  end
end
