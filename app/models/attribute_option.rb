class AttributeOption < ApplicationRecord
  COLORS = %w[neutral primary secondary accent info success warning error].freeze

  belongs_to :attribute_definition, inverse_of: :attribute_options

  validates :value, presence: true,
                    format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ },
                    uniqueness: { scope: :attribute_definition_id }
  validates :label, presence: true
  validates :color, inclusion: { in: COLORS }, allow_blank: true
end
