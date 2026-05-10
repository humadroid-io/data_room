class Customer < ApplicationRecord
  include HasCustomAttributes

  has_many :subscriptions, dependent: :destroy
  has_many :payments,      dependent: :destroy

  CHURN_REASONS = {
    price:           0,
    competitor:      1,
    features:        2,
    low_usage:       3,
    contraction:     4,
    acquired:        5,
    closed:          6,
    internal_change: 7,
    other:           8
  }.freeze

  enum :churn_reason_category, CHURN_REASONS, prefix: true

  validates :name, presence: true
  validates :stripe_customer_id, uniqueness: true, allow_blank: true
  validate  :reason_requires_churn_date

  scope :reference_capable, -> { where(reference_call_ok: true) }
  scope :active,            -> { where(churned_on: nil) }
  scope :churned,           -> { where.not(churned_on: nil) }
  scope :churned_in_period, ->(from, to) {
    rel = churned
    rel = rel.where(churned_on: from..) if from
    rel = rel.where(churned_on: ..to)   if to
    rel
  }

  scope :with_custom_attribute, ->(key, value) {
    where("json_extract(custom_attributes, ?) = ?", "$.#{sanitize_json_key(key)}", value)
  }

  scope :with_custom_attribute_containing, ->(key, value) {
    where(
      "EXISTS (SELECT 1 FROM json_each(json_extract(custom_attributes, ?)) WHERE json_each.value = ?)",
      "$.#{sanitize_json_key(key)}",
      value
    )
  }

  def churned?
    churned_on.present?
  end

  def self.sanitize_json_key(key)
    raise ArgumentError, "invalid attribute key" unless key.to_s.match?(/\A[a-z][a-z0-9_]*\z/)
    key.to_s
  end

  private

  def reason_requires_churn_date
    return if churned?
    if churn_reason_category.present? || churn_reason_notes.present?
      errors.add(:churned_on, "must be set when a churn reason is recorded")
    end
  end
end
