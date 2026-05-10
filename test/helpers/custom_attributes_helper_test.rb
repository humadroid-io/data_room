require "test_helper"

class CustomAttributesHelperTest < ActionView::TestCase
  # custom_attribute_field needs a form builder; build a minimal one bound
  # to a Customer so `form.object_name` returns "customer".
  def form_for(record)
    template = ActionView::Base.with_empty_template_cache.new(
      ActionController::Base.view_paths,
      {},
      ActionController::Base.new
    )
    ActionView::Helpers::FormBuilder.new(record.model_name.param_key, record, template, {})
  end

  setup { @form = form_for(Customer.new) }

  # --- single_select with various current values ---------------------------

  test "single_select renders a leading 'none' option" do
    defn = create(:single_select_attribute, key: "stage", label: "Stage")
    html = custom_attribute_field(@form, defn, nil)

    assert_match(/<option[^>]*value=""[^>]*>— none —<\/option>/, html)
  end

  test "single_select marks 'none' selected when current value is nil" do
    defn = create(:single_select_attribute, key: "stage", label: "Stage")
    html = custom_attribute_field(@form, defn, nil)

    assert_match(/<option[^>]*selected[^>]*value=""[^>]*>— none —<\/option>/, html)
  end

  test "single_select marks 'none' selected when current value is empty string" do
    defn = create(:single_select_attribute, key: "stage", label: "Stage")
    html = custom_attribute_field(@form, defn, "")

    assert_match(/<option[^>]*selected[^>]*value=""[^>]*>— none —<\/option>/, html)
  end

  test "single_select marks the matching real option as selected" do
    defn = create(:single_select_attribute, key: "stage", label: "Stage")
    html = custom_attribute_field(@form, defn, "a")

    assert_match(/<option[^>]*selected[^>]*value="a"[^>]*>A<\/option>/, html)
    refute_match(/<option[^>]*selected[^>]*value=""[^>]*>— none —/, html)
  end

  test "single_select uses the correct field name format" do
    defn = create(:single_select_attribute, key: "stage", label: "Stage")
    html = custom_attribute_field(@form, defn, nil)

    assert_match 'name="customer[custom_attributes][stage]"', html
  end
end
