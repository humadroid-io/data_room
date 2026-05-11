class AttributeDefinition < ApplicationRecord
  DATA_TYPES = %i[
    string text integer decimal date boolean
    single_select multi_select
  ].freeze

  enum :data_type, DATA_TYPES

  has_many :attribute_options, -> { order(:sort_order) },
           dependent: :destroy, inverse_of: :attribute_definition

  accepts_nested_attributes_for :attribute_options,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs[:value].blank? && attrs[:label].blank? }

  validates :resource_type, presence: true
  validates :label,         presence: true
  validates :key, presence: true,
                  format: { with: /\A[a-z][a-z0-9_]*\z/ },
                  uniqueness: { scope: :resource_type }

  validate :select_types_have_options

  scope :for_resource, ->(klass) {
    where(resource_type: klass.to_s).order(:sort_order)
  }
  scope :captured, -> { where(capture_on_snapshot: true) }

  def select_type?
    single_select? || multi_select?
  end

  private

  def select_types_have_options
    return unless select_type?
    return if attribute_options.reject(&:marked_for_destruction?).any?

    errors.add(:attribute_options, "must include at least one option for select types")
  end
end
