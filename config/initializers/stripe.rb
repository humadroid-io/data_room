# Stripe sync configuration is read on every call from
# `app/services/stripe_config.rb` (so YAML edits don't require a restart).
# Only the API key is bound here — using to_prepare so app constants
# (StripeConfig lives in app/services) are available.

Rails.application.config.to_prepare do
  Stripe.api_key = StripeConfig.api_key if StripeConfig.api_key.present?
end
