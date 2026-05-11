class Subscription < ApplicationRecord
  include HasCustomAttributes

  belongs_to :customer
  has_many :snapshots, dependent: :destroy
  has_many :payments,  dependent: :nullify

  enum :status, %i[active past_due canceled paused trialing incomplete], default: :active

  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_customer_id,     presence: true
  validates :mrr_cents,              numericality: { greater_than_or_equal_to: 0 }

  before_save :recompute_mrr_cents_usd
  after_save  :recheck_customer_churn

  scope :active_now,  -> { where(status: %i[active trialing]) }
  scope :for_product, ->(code) { where(product_code: code) }

  # The friendly product name when set, else the raw Stripe price ID, else "—".
  def display_product
    product_code.presence || stripe_price_id.presence || "—"
  end

  def mrr
    mrr_cents / 100.0
  end

  def mrr_usd
    mrr_cents_usd / 100.0
  end

  # Post-discount monthly value. Takes the most recent payment for this sub
  # and amortizes it over the billing interval — so a $1080 annual payment
  # (10% off a $100/mo list) shows as $90/mo effective, not $100.
  # Falls back to nominal `mrr_cents_usd` when no payments exist yet.
  def effective_mrr_cents_usd(as_of: nil)
    relation = payments
    relation = relation.where("paid_at <= ?", as_of) if as_of
    latest = relation.order(paid_at: :desc).first
    return mrr_cents_usd unless latest

    interval = [ interval_months.to_i, 1 ].max
    (latest.amount_cents_usd.to_f / interval).round
  end

  private

  def recompute_mrr_cents_usd
    self.mrr_cents_usd = CurrencyConverter.to_usd_cents(mrr_cents.to_i, currency.presence || "usd")
  end

  def recheck_customer_churn
    customer&.auto_detect_churn!
  end
end
