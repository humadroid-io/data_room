module Admin::PaymentsHelper
  def payment_amount(payment)
    format_money(payment.amount_cents, payment.currency)
  end

  def format_money(cents, currency)
    symbol = currency_symbol(currency)
    "#{symbol}#{number_with_delimiter((cents || 0) / 100)}"
  end

  def currency_symbol(code)
    {
      "usd" => "$", "eur" => "€", "gbp" => "£", "pln" => "zł ",
      "jpy" => "¥", "cad" => "CA$", "aud" => "A$"
    }.fetch(code.to_s.downcase, "#{code.to_s.upcase} ")
  end

  def payment_product_label(payment)
    payment.subscription&.display_product || tag.span("one-off", class: "text-base-content/40 italic")
  end
end
