class Payment < ApplicationRecord
  belongs_to :customer
  belongs_to :subscription, optional: true

  validates :stripe_invoice_id, presence: true, uniqueness: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :paid_at, presence: true

  before_save :recompute_amount_cents_usd

  scope :by_paid_at, -> { order(paid_at: :desc) }

  # Re-link payments that have a customer but no subscription. For each
  # orphan, pick the subscription that was active when the payment was made
  # (started_at <= paid_at AND canceled_at IS NULL OR >= paid_at). When the
  # customer has exactly one such match, link it. Ambiguous matches are
  # left alone (admin can resolve manually).
  def self.backfill_subscriptions!
    relinked = 0
    where(subscription_id: nil).includes(customer: :subscriptions).find_each do |payment|
      candidates = payment.customer.subscriptions.select do |s|
        (s.started_at.nil?  || s.started_at  <= payment.paid_at) &&
        (s.canceled_at.nil? || s.canceled_at >= payment.paid_at)
      end
      next unless candidates.size == 1
      payment.update_column(:subscription_id, candidates.first.id)
      relinked += 1
    end
    relinked
  end

  def amount
    amount_cents / 100.0
  end

  def amount_usd
    amount_cents_usd / 100.0
  end

  private

  def recompute_amount_cents_usd
    self.amount_cents_usd = CurrencyConverter.to_usd_cents(amount_cents.to_i, currency.presence || "usd")
  end
end
