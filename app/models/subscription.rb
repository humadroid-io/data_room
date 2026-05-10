class Subscription < ApplicationRecord
  include HasCustomAttributes

  belongs_to :customer
  has_many :snapshots, dependent: :destroy
  has_many :payments,  dependent: :nullify

  enum :status, %i[active past_due canceled paused trialing incomplete], default: :active

  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_customer_id,     presence: true
  validates :mrr_cents,              numericality: { greater_than_or_equal_to: 0 }

  scope :active_now,  -> { where(status: %i[active trialing]) }
  scope :for_product, ->(code) { where(product_code: code) }

  # The friendly product name when set, else the raw Stripe price ID, else "—".
  # Use this anywhere you'd otherwise read `product_code` for display.
  def display_product
    product_code.presence || stripe_price_id.presence || "—"
  end

  def mrr
    mrr_cents / 100.0
  end
end
