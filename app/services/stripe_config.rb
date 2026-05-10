require "yaml"

# Reads config/stripe_products.yml on every call. No boot-time freezing —
# editing the YAML in development takes effect on the next sync run, no
# server restart needed. In production, deploys restart the app anyway,
# so the per-call YAML read is wasted work but trivially cheap.
module StripeConfig
  module_function

  MODES = %i[none all paying].freeze

  def customer_import_mode
    mode = (env_config["customer_import"] || "none").to_sym
    raise "Invalid customer_import: #{mode.inspect} — must be one of #{MODES}" unless MODES.include?(mode)
    mode
  end

  def products
    raw = env_config["products"] || env_config_legacy_products
    raw.transform_keys(&:to_s)
  end

  # Returns the mapped product_code, or nil when the price isn't in the map.
  # Callers should fall back to the raw stripe_price_id for display.
  def product_code_for(price_id)
    return nil if price_id.blank?
    products[price_id.to_s]
  end

  def api_key
    Rails.application.credentials.dig(:stripe, :api_key) || ENV["STRIPE_API_KEY"]
  end

  def configured?
    api_key.present?
  end

  def env_config
    raw = load_yaml
    cfg = raw[Rails.env]
    cfg.is_a?(Hash) ? cfg : {}
  end

  def env_config_legacy_products
    # Backward compat: if the env block is a flat price→product hash with no
    # "products"/"customer_import" keys, treat the whole thing as products.
    cfg = env_config
    return {} if cfg.key?("products") || cfg.key?("customer_import")
    cfg
  end

  def load_yaml
    YAML.load_file(Rails.root.join("config/stripe_products.yml")) || {}
  rescue Errno::ENOENT
    {}
  end
end
