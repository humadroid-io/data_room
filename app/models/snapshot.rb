class Snapshot < ApplicationRecord
  belongs_to :subscription

  enum :status, %i[active past_due canceled paused trialing incomplete]

  delegate :customer, to: :subscription

  validates :snapshot_date, presence: true,
                            uniqueness: { scope: :subscription_id }
  validates :mrr_cents,     numericality: { greater_than_or_equal_to: 0 }

  before_save :recompute_mrr_cents_usd

  def captured_attribute(key)
    captured_attributes[key.to_s]
  end

  private

  def recompute_mrr_cents_usd
    currency = subscription&.currency || "usd"
    self.mrr_cents_usd = CurrencyConverter.to_usd_cents(mrr_cents.to_i, currency)
  end
end
