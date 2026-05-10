module HasCustomAttributes
  extend ActiveSupport::Concern

  included do
    validate :validate_custom_attributes
  end

  def custom_attribute(key)
    custom_attributes[key.to_s]
  end

  def set_custom_attribute(key, value)
    self.custom_attributes = (custom_attributes || {}).merge(key.to_s => value)
  end

  def attribute_definitions
    AttributeDefinition.for_resource(self.class)
  end

  def custom_attribute_label(key)
    defn = attribute_definitions.find { |d| d.key == key.to_s }
    return nil unless defn

    value = custom_attribute(key)
    return value if value.blank?
    return value unless %w[single_select multi_select].include?(defn.data_type)

    options_map = (defn.options || []).index_by { |o| o["value"] }
    if defn.single_select?
      options_map[value]&.dig("label") || value
    else
      Array(value).map { |v| options_map[v]&.dig("label") || v }
    end
  end

  def captured_attributes_for_snapshot
    keys = attribute_definitions.captured.pluck(:key)
    (custom_attributes || {}).slice(*keys)
  end

  private

  def validate_custom_attributes
    attribute_definitions.each do |defn|
      value = custom_attribute(defn.key)

      if defn.required && value.blank?
        errors.add(:custom_attributes, "#{defn.label} is required")
        next
      end

      next if value.blank?

      case defn.data_type
      when "integer"
        unless value.to_s.match?(/\A-?\d+\z/)
          errors.add(:custom_attributes, "#{defn.label} must be an integer")
        end
      when "decimal"
        unless value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
          errors.add(:custom_attributes, "#{defn.label} must be a number")
        end
      when "date"
        begin
          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          errors.add(:custom_attributes, "#{defn.label} is not a valid date")
        end
      when "single_select"
        valid = (defn.options || []).map { |o| o["value"] }
        unless valid.include?(value)
          errors.add(:custom_attributes, "#{defn.label} has invalid value")
        end
      when "multi_select"
        unless value.is_a?(Array)
          errors.add(:custom_attributes, "#{defn.label} must be an array")
        else
          valid = (defn.options || []).map { |o| o["value"] }
          if (value - valid).any?
            errors.add(:custom_attributes, "#{defn.label} has invalid values")
          end
        end
      end
    end
  end
end
