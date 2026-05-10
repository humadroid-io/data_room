require "test_helper"

class Admin::EventsHelperTest < ActionView::TestCase
  test "event_kind_badge renders titleized kind text" do
    assert_match "Funding",     event_kind_badge(build(:event, kind: :funding))
    assert_match "Partnership", event_kind_badge(build(:event, kind: :partnership))
  end

  test "event_kind_badge styles the badge with the kind's color" do
    html = event_kind_badge(build(:event, kind: :risk))
    assert_match "#dc2626", html
  end
end
