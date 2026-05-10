require "test_helper"

class Admin::DashboardsHelperTest < ActionView::TestCase
  # --- stripe_api_key_badge -------------------------------------------------

  test "stripe_api_key_badge renders Set when configured" do
    html = stripe_api_key_badge(true)
    assert_match "Set", html
    assert_match "badge-success", html
  end

  test "stripe_api_key_badge renders Missing with hint when not configured" do
    html = stripe_api_key_badge(false)
    assert_match "Missing", html
    assert_match "badge-error", html
    assert_match "STRIPE_API_KEY", html
  end

  # --- customer_import_badge ------------------------------------------------

  test "customer_import_badge maps each known mode to a labeled badge" do
    assert_match ">None<",        customer_import_badge(:none)
    assert_match ">All<",         customer_import_badge(:all)
    assert_match ">Paying only<", customer_import_badge(:paying)

    assert_match "badge-info",    customer_import_badge(:all)
    assert_match "badge-success", customer_import_badge(:paying)
  end

  test "customer_import_badge accepts string values" do
    assert_match ">All<", customer_import_badge("all")
  end

  test "customer_import_badge falls back to a plain badge for unknown modes" do
    html = customer_import_badge(:something_new)
    assert_match "something_new", html
    assert_match "class=\"badge\"", html
  end

  # --- last_sync_summary_text ----------------------------------------------

  test "last_sync_summary_text formats the counts" do
    assert_equal "5 customers · 3 subscriptions",
                 last_sync_summary_text(customers: 5, subscriptions: 3)
  end

  test "last_sync_summary_text returns nil when summary is blank" do
    assert_nil last_sync_summary_text(nil)
    assert_nil last_sync_summary_text({})
  end

  # --- mrr_dollars ----------------------------------------------------------

  test "mrr_dollars converts cents to a delimited dollar string" do
    assert_equal "$1,234",  mrr_dollars(123_456)
    assert_equal "$0",      mrr_dollars(0)
    assert_equal "$0",      mrr_dollars(nil)
    assert_equal "$10,000", mrr_dollars(1_000_000)
  end

  # --- page_view_row_time ---------------------------------------------------

  test "page_view_row_time formats ago text" do
    travel_to Time.utc(2026, 5, 10, 12, 0, 0) do
      assert_equal "5 minutes ago", page_view_row_time(5.minutes.ago)
    end
  end
end
