module CustomAttributesHelper
  def custom_attribute_field(form, defn, current_value)
    case defn.data_type
    when "string"
      content_tag(:input, "", type: "text", name: custom_attribute_field_name(form, defn), value: current_value,
                  class: "input input-bordered w-full")
    when "text"
      content_tag(:textarea, current_value.to_s, name: custom_attribute_field_name(form, defn), rows: 3,
                  class: "textarea textarea-bordered w-full")
    when "integer"
      content_tag(:input, "", type: "number", step: "1", name: custom_attribute_field_name(form, defn),
                  value: current_value, class: "input input-bordered w-full")
    when "decimal"
      content_tag(:input, "", type: "number", step: "0.01", name: custom_attribute_field_name(form, defn),
                  value: current_value, class: "input input-bordered w-full")
    when "date"
      content_tag(:input, "", type: "date", name: custom_attribute_field_name(form, defn), value: current_value,
                  class: "input input-bordered w-full")
    when "boolean"
      content_tag(:label, class: "flex items-center gap-2 cursor-pointer") do
        check  = tag.input(type: "hidden", name: custom_attribute_field_name(form, defn), value: "0")
        check += tag.input(type: "checkbox", name: custom_attribute_field_name(form, defn), value: "1",
                           checked: ActiveModel::Type::Boolean.new.cast(current_value),
                           class: "checkbox checkbox-sm")
        check += tag.span(defn.label, class: "text-sm")
        check
      end
    when "single_select"
      # Prepend the blank option so options_for_select can mark it selected
      # when current_value is nil/"". Otherwise nothing appears chosen.
      choices = [ [ "— none —", "" ] ] + defn.attribute_options.map { |o| [ o.label, o.value ] }
      content_tag(:select, options_for_select(choices, current_value.to_s),
                  name: custom_attribute_field_name(form, defn), class: "select select-bordered w-full")
    when "multi_select"
      content_tag(:div, class: "flex flex-wrap gap-3 p-2 border border-base-300 rounded-md") do
        hidden = tag.input(type: "hidden", name: "#{custom_attribute_field_name(form, defn)}[]", value: "")
        opts = defn.attribute_options.map do |o|
          checked = Array(current_value).include?(o.value)
          tag.label(class: "flex items-center gap-2 text-sm cursor-pointer") do
            tag.input(type: "checkbox",
                      name: "#{custom_attribute_field_name(form, defn)}[]",
                      value: o.value,
                      checked: checked,
                      class: "checkbox checkbox-xs") + tag.span(o.label)
          end
        end
        safe_join([ hidden ] + opts)
      end
    end
  end

  def custom_attribute_badge(defn, value)
    return content_tag(:span, "—", class: "text-base-content/40") if value.blank?

    case defn.data_type
    when "single_select"
      opt = defn.attribute_options.find { |o| o.value == value }
      label = opt&.label || value
      color = opt&.color.presence || "neutral"
      content_tag(:span, label, class: "badge badge-soft badge-#{color}")
    when "multi_select"
      opts_map = defn.attribute_options.index_by(&:value)
      safe_join(Array(value).map { |v|
        opt = opts_map[v]
        content_tag(:span, opt&.label || v,
                    class: "badge badge-soft badge-#{opt&.color.presence || 'neutral'} mr-1")
      })
    when "boolean"
      content_tag(:span, value ? "Yes" : "No", class: "badge badge-sm")
    when "date"
      content_tag(:span, value)
    else
      content_tag(:span, value.to_s)
    end
  end

  def custom_attribute_field_name(form, defn)
    "#{form.object_name}[custom_attributes][#{defn.key}]"
  end
end
