class AttributeDefinition < ApplicationRecord
  DATA_TYPES = %i[
    string text integer decimal date boolean
    single_select multi_select
  ].freeze

  enum :data_type, DATA_TYPES

  validates :resource_type, presence: true
  validates :label,         presence: true
  validates :key, presence: true,
                  format: { with: /\A[a-z][a-z0-9_]*\z/ },
                  uniqueness: { scope: :resource_type }

  scope :for_resource, ->(klass) {
    where(resource_type: klass.to_s).order(:sort_order)
  }
  scope :captured, -> { where(capture_on_snapshot: true) }

  def select_type?
    single_select? || multi_select?
  end
end
