require "test_helper"

class Admin::EventsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_admin }

  test "GET show renders event details" do
    event = create(:event, title: "Series A", kind: :funding,
                            occurred_on: Date.new(2026, 4, 15),
                            description: "Closed $5M lead by VastFund.")
    get admin_event_path(event)
    assert_response :success
    assert_match "Series A",       response.body
    assert_match "VastFund",        response.body
    assert_match event.month_bucket, response.body
  end

  test "GET show requires admin sign-in" do
    event = create(:event)
    delete admin_logout_path
    get admin_event_path(event)
    assert_redirected_to admin_login_path
  end

  test "GET index lists events most-recent first" do
    older = create(:event, occurred_on: Date.new(2025, 12, 1), title: "Old")
    newer = create(:event, occurred_on: Date.new(2026, 5, 1),  title: "New")

    get admin_events_path
    assert_response :success
    body = response.body
    new_pos = body.index("New")
    old_pos = body.index("Old")
    assert new_pos && old_pos
    assert_operator new_pos, :<, old_pos
  end

  test "GET new pre-fills today's date" do
    get new_admin_event_path
    assert_response :success
    assert_select "input[type=date][value=?]", Date.current.to_s
  end

  test "POST create persists an event" do
    assert_difference -> { Event.count }, 1 do
      post admin_events_path, params: {
        event: { title: "Series A", occurred_on: "2026-04-15", kind: "funding",
                 description: "$5M raise." }
      }
    end
    assert_redirected_to admin_events_path
    assert_equal "funding", Event.last.kind
  end

  test "POST create rejects missing title" do
    post admin_events_path, params: { event: { occurred_on: Date.current, kind: "other" } }
    assert_response :unprocessable_entity
  end

  test "PATCH update changes attributes" do
    event = create(:event, kind: :other, title: "Old")
    patch admin_event_path(event), params: { event: { title: "Updated", kind: "milestone" } }
    assert_redirected_to admin_events_path
    assert_equal "Updated",   event.reload.title
    assert_equal "milestone", event.reload.kind
  end

  test "DELETE removes the event" do
    event = create(:event)
    assert_difference -> { Event.count }, -1 do
      delete admin_event_path(event)
    end
  end

  test "requires admin sign-in" do
    delete admin_logout_path
    get admin_events_path
    assert_redirected_to admin_login_path
  end
end
