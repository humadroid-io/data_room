class Payment < ApplicationRecord
  belongs_to :customer
  belongs_to :subscription, optional: true

  validates :stripe_invoice_id, presence: true, uniqueness: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :paid_at, presence: true

  scope :by_paid_at, -> { order(paid_at: :desc) }

  def amount
    amount_cents / 100.0
  end
end
