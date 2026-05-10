require "test_helper"

class PagesHelperTest < ActionView::TestCase
  setup do
    @investor = create(:investor)
    @page     = create(:section_page, slug: "p")
  end

  test "render_page_body replaces CHILD_PAGES token" do
    create(:child_page, slug: "child-1", parent_page: @page, title: "Child One")
    @page.body = "Intro [CHILD_PAGES] outro"
    @page.save!

    rendered = render_page_body(@page, @investor)
    assert_match "Intro", rendered
    assert_match "Child One", rendered
    assert_match "outro", rendered
  end

  test "render_page_body hides children that the investor can't see" do
    visible = create(:child_page, slug: "v", parent_page: @page, title: "Visible")
    secret  = create(:child_page, slug: "s", parent_page: @page, title: "Secret",
                                  visibility: :private)

    @page.body = "[CHILD_PAGES]"
    @page.save!

    rendered = render_page_body(@page, @investor)
    assert_match "Visible", rendered
    assert_no_match(/Secret/, rendered)
  end

  test "leaves unknown tokens alone" do
    @page.body = "[UNKNOWN_TOKEN]"
    @page.save!
    assert_match "[UNKNOWN_TOKEN]", render_page_body(@page, @investor)
  end

  # --- monthly_revenue_chart_data ------------------------------------------

  test "monthly_revenue_chart_data returns one series per mapped product" do
    customer = create(:customer)
    sub_a = create(:subscription, customer: customer, product_code: "alpha", stripe_price_id: "price_a")
    sub_b = create(:subscription, customer: customer, product_code: "beta",  stripe_price_id: "price_b")
    create(:payment, customer: customer, subscription: sub_a, amount_cents: 5_000, paid_at: Date.new(2026, 5, 15))
    create(:payment, customer: customer, subscription: sub_a, amount_cents: 7_000, paid_at: Date.new(2026, 6, 10))
    create(:payment, customer: customer, subscription: sub_b, amount_cents: 4_000, paid_at: Date.new(2026, 6, 12))

    series = monthly_revenue_chart_data
    alpha = series.find { |s| s[:name] == "Alpha" }
    beta  = series.find { |s| s[:name] == "Beta" }

    assert_equal({ "2026-05" => 50, "2026-06" => 70 }, alpha[:data])
    assert_equal({ "2026-06" => 40 }, beta[:data])
  end

  test "monthly_revenue_chart_data falls back to stripe_price_id when product_code is nil" do
    customer = create(:customer)
    sub = create(:subscription, customer: customer, product_code: nil, stripe_price_id: "price_unmapped")
    create(:payment, customer: customer, subscription: sub, amount_cents: 1_000, paid_at: Date.new(2026, 5, 1))

    series = monthly_revenue_chart_data
    assert_equal "Price Unmapped", series.first[:name]
  end

  test "monthly_revenue_chart_data labels payments without a subscription as 'Other'" do
    customer = create(:customer)
    create(:payment, customer: customer, subscription: nil, amount_cents: 2_500, paid_at: Date.new(2026, 5, 1))

    series = monthly_revenue_chart_data
    assert_equal "Other", series.first[:name]
    assert_equal({ "2026-05" => 25 }, series.first[:data])
  end

  test "monthly_revenue_chart_data is empty when no payments exist" do
    assert_empty monthly_revenue_chart_data
  end

  # --- chart_event_annotations --------------------------------------------

  test "chart_event_annotations returns one entry per event keyed by id" do
    e1 = create(:event, title: "Series A", kind: :funding, occurred_on: Date.new(2026, 5, 15))
    e2 = create(:event, title: "Layoffs",  kind: :risk,    occurred_on: Date.new(2026, 6, 1))

    annotations = chart_event_annotations([ e1, e2 ])

    assert_equal 2, annotations.size
    assert_equal "2026-05",   annotations["event_#{e1.id}"][:xMin]
    assert_equal "Series A",  annotations["event_#{e1.id}"][:label][:content]
    assert_equal "#16a34a",   annotations["event_#{e1.id}"][:borderColor]
    assert_equal "#dc2626",   annotations["event_#{e2.id}"][:borderColor]
    assert_equal "line",      annotations["event_#{e1.id}"][:type]
  end

  test "chart_event_annotations is empty when no events given" do
    assert_empty chart_event_annotations([])
    assert_empty chart_event_annotations(nil)
  end

  # --- chart_zoom_options --------------------------------------------------

  test "chart_zoom_options enables wheel/pinch/drag on the x-axis only" do
    opts = chart_zoom_options
    assert_equal "x", opts[:zoom][:mode]
    assert_equal "x", opts[:pan][:mode]
    assert opts[:zoom][:wheel][:enabled]
    assert opts[:zoom][:pinch][:enabled]
    assert opts[:zoom][:drag][:enabled]
    assert_equal "ctrl", opts[:zoom][:wheel][:modifierKey]
  end

  # --- monthly_revenue_widget ---------------------------------------------

  test "monthly_revenue_widget bundles data, events, chart_id and library" do
    customer = create(:customer)
    sub = create(:subscription, customer: customer, product_code: "alpha")
    create(:payment, customer: customer, subscription: sub, amount_cents: 1_000, paid_at: Date.new(2026, 5, 1))
    create(:event, occurred_on: Date.new(2026, 5, 15), title: "Series A")

    w = monthly_revenue_widget

    assert w[:data].any?
    assert_equal 1, w[:events].size
    assert_match(/\Amonthly-revenue-/, w[:chart_id])

    plugins = w[:library][:plugins]
    assert plugins[:annotation][:annotations].any?
    assert plugins[:zoom][:zoom][:wheel][:enabled]
    assert_equal "bottom", plugins[:legend][:position]
  end

  # --- retention_cohort_widget --------------------------------------------

  test "retention_cohort_widget returns key: nil when no captured attribute exists" do
    w = retention_cohort_widget(nil)
    assert_nil w[:key]
  end

  test "retention_cohort_widget falls back to first captured attribute when no key passed" do
    create(:captured_attribute, key: "stage")
    w = retention_cohort_widget(nil)
    assert_equal "stage", w[:key]
    assert_match(/\Aretention-cohort-/, w[:chart_id])
  end

  test "retention_cohort_widget honors an explicitly passed key" do
    create(:captured_attribute, key: "stage")
    create(:captured_attribute, key: "lifecycle", options: [ { "value" => "x", "label" => "X" } ])
    w = retention_cohort_widget("lifecycle")
    assert_equal "lifecycle", w[:key]
  end

  test "retention_cohort_widget includes zoom plugin in library" do
    create(:captured_attribute, key: "stage")
    w = retention_cohort_widget("stage")
    assert w[:library][:plugins][:zoom][:zoom][:wheel][:enabled]
  end

  # --- churn widgets ------------------------------------------------------

  test "churned_customers_widget returns rows ordered by most-recent churn" do
    create(:churned_customer, churned_on: Date.new(2026, 1, 1), name: "Older")
    create(:churned_customer, churned_on: Date.new(2026, 5, 1), name: "Newer",
                              churn_reason_category: :competitor,
                              churn_reason_notes: "Switched to BigCorp")
    create(:customer, name: "Active")

    rows = churned_customers_widget
    assert_equal 2, rows.size
    assert_equal "Newer",      rows.first[:label]
    assert_equal "Older",      rows.last[:label]
    assert_equal "Competitor", rows.first[:category_text]
    assert_equal "Switched to BigCorp", rows.first[:notes]
  end

  test "churned_customers_widget prefers anonymized_label over name" do
    create(:churned_customer, name: "Real Co", anonymized_label: "AI SaaS, 12 employees")
    rows = churned_customers_widget
    assert_equal "AI SaaS, 12 employees", rows.first[:label]
  end

  test "churn_reasons_breakdown counts categorized churns by reason, descending" do
    create(:churned_customer, churn_reason_category: :price)
    create(:churned_customer, churn_reason_category: :price)
    create(:churned_customer, churn_reason_category: :competitor)
    create(:churned_customer, churn_reason_category: nil) # excluded

    breakdown = churn_reasons_breakdown
    assert_equal 2, breakdown["price"]
    assert_equal 1, breakdown["competitor"]
    assert_equal "price", breakdown.keys.first  # sorted by count desc
  end

  test "churn_reasons_breakdown is empty when no categorized churns exist" do
    create(:customer)
    create(:churned_customer, churn_reason_category: nil)
    assert_empty churn_reasons_breakdown
  end

  test "monthly_churn_rate computes percent of active customers churned per month" do
    travel_to Date.new(2026, 6, 15) do
      # 4 customers active at start of May 2026, 1 churns in May → 25%.
      4.times { create(:customer, created_at: Date.new(2026, 1, 1)) }
      Customer.first.update!(churned_on: Date.new(2026, 5, 10))

      rate = monthly_churn_rate(months_back: 2)
      assert_equal 25.0, rate["2026-05"]
      assert_equal 0.0,  rate["2026-04"]
    end
  end

  test "monthly_churn_rate returns 0 when no customers were active" do
    travel_to Date.new(2026, 6, 15) do
      assert_equal 0.0, monthly_churn_rate(months_back: 1)["2026-05"]
    end
  end

  test "churn_rate_widget bundles data, chart_id, and library with zoom" do
    w = churn_rate_widget
    assert w[:data].is_a?(Array)
    assert_match(/\Achurn-rate-/, w[:chart_id])
    assert w[:library][:plugins][:zoom][:zoom][:wheel][:enabled]
  end

  # --- mrr_movements ------------------------------------------------------

  test "mrr_movements returns all-zero buckets when there is no subscription data" do
    movements = mrr_movements
    assert movements.any?, "expected the trailing window to be populated"
    assert(movements.values.all? { |m| m[:start_mrr].zero? && m[:new].zero? })
  end

  test "mrr_movements derives from current subscriptions when no snapshots exist" do
    travel_to Date.new(2026, 5, 15) do
      cust = create(:customer)
      # Active throughout April and May (started Jan, never canceled)
      create(:subscription, customer: cust, mrr_cents: 10_000,
                            started_at: Date.new(2026, 1, 1), canceled_at: nil)

      m = mrr_movements["2026-05"]
      assert_equal 100, m[:start_mrr]    # was at $100 in April
      assert_equal 0,   m[:new]
      assert_equal 0,   m[:churn]
    end
  end

  test "mrr_movements still prefers snapshot data when present" do
    travel_to Date.new(2026, 5, 15) do
      cust = create(:customer)
      sub  = create(:subscription, customer: cust, mrr_cents: 99_999,
                                   started_at: Date.new(2026, 1, 1))
      # Snapshot says april MRR was $200, even though current is $999.99
      create(:snapshot, subscription: sub, snapshot_date: Date.new(2026, 4, 1),
                        mrr_cents: 20_000, status: :active)
      create(:snapshot, subscription: sub, snapshot_date: Date.new(2026, 5, 1),
                        mrr_cents: 20_000, status: :active)

      assert_equal 200, mrr_movements["2026-05"][:start_mrr]
    end
  end

  test "mrr_movements categorises new / expansion / contraction / churn" do
    cust_keep   = create(:customer, name: "Keep")
    cust_new    = create(:customer, name: "New")
    cust_grow   = create(:customer, name: "Grow")
    cust_shrink = create(:customer, name: "Shrink")
    cust_left   = create(:customer, name: "Left")

    sub_keep   = create(:subscription, customer: cust_keep)
    sub_new    = create(:subscription, customer: cust_new)
    sub_grow   = create(:subscription, customer: cust_grow)
    sub_shrink = create(:subscription, customer: cust_shrink)
    sub_left   = create(:subscription, customer: cust_left)

    apr = Date.new(2026, 4, 1)
    may = Date.new(2026, 5, 1)

    # April baseline (everyone except 'New' is paying $100)
    create(:snapshot, subscription: sub_keep,   snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub_grow,   snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub_shrink, snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub_left,   snapshot_date: apr, mrr_cents: 10_000, status: :active)

    # May: keep flat, new appears, grow doubles, shrink halves, left is gone
    create(:snapshot, subscription: sub_keep,   snapshot_date: may, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub_new,    snapshot_date: may, mrr_cents:  5_000, status: :active)
    create(:snapshot, subscription: sub_grow,   snapshot_date: may, mrr_cents: 20_000, status: :active)
    create(:snapshot, subscription: sub_shrink, snapshot_date: may, mrr_cents:  5_000, status: :active)

    m = mrr_movements["2026-05"]
    assert_equal 400, m[:start_mrr]    # 4 × $100 in April
    assert_equal 50,  m[:new]          # New @ $50
    assert_equal 100, m[:expansion]    # Grow +$100
    assert_equal 50,  m[:contraction]  # Shrink −$50
    assert_equal 100, m[:churn]        # Left dropped $100
  end

  # --- mrr_walk_widget ----------------------------------------------------

  test "mrr_walk_widget returns four series with negatives for losses" do
    customer = create(:customer)
    sub = create(:subscription, customer: customer)
    apr = Date.new(2026, 4, 1)
    may = Date.new(2026, 5, 1)
    create(:snapshot, subscription: sub, snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub, snapshot_date: may, mrr_cents:  5_000, status: :active)

    w = mrr_walk_widget
    assert_equal %w[New Expansion Contraction Churn], w[:data].map { |s| s[:name] }
    assert_equal(-50, w[:data][2][:data]["2026-05"])  # contraction surfaced negative
  end

  # --- nrr_grr_widget -----------------------------------------------------

  test "nrr_grr_widget computes percentages relative to start MRR" do
    cust_grow = create(:customer)
    cust_lost = create(:customer)
    sub_grow  = create(:subscription, customer: cust_grow)
    sub_lost  = create(:subscription, customer: cust_lost)
    apr = Date.new(2026, 4, 1)
    may = Date.new(2026, 5, 1)
    create(:snapshot, subscription: sub_grow, snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub_lost, snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub_grow, snapshot_date: may, mrr_cents: 12_000, status: :active)
    # cust_lost gone in May → churn

    w = nrr_grr_widget
    nrr = w[:data].find { |s| s[:name] == "NRR" }[:data]["2026-05"]
    grr = w[:data].find { |s| s[:name] == "GRR" }[:data]["2026-05"]
    # start = $200, expansion = $20, churn = $100
    # NRR = (200 + 20 - 0 - 100) / 200 = 60%
    # GRR = (200 - 0 - 100) / 200 = 50%
    assert_equal 60.0, nrr
    assert_equal 50.0, grr
  end

  # --- quick_ratio_widget -------------------------------------------------

  test "quick_ratio_widget skips months with no losses" do
    customer = create(:customer)
    sub = create(:subscription, customer: customer)
    apr = Date.new(2026, 4, 1)
    may = Date.new(2026, 5, 1)
    create(:snapshot, subscription: sub, snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub, snapshot_date: may, mrr_cents: 12_000, status: :active)
    # only expansion, no losses → quick ratio undefined → omitted

    assert_empty quick_ratio_widget[:data]
  end

  test "quick_ratio_widget computes (gain / loss)" do
    cust_grow = create(:customer)
    cust_lost = create(:customer)
    sub_grow  = create(:subscription, customer: cust_grow)
    sub_lost  = create(:subscription, customer: cust_lost)
    apr = Date.new(2026, 4, 1)
    may = Date.new(2026, 5, 1)
    create(:snapshot, subscription: sub_grow, snapshot_date: apr, mrr_cents: 10_000, status: :active)
    create(:snapshot, subscription: sub_lost, snapshot_date: apr, mrr_cents:  5_000, status: :active)
    create(:snapshot, subscription: sub_grow, snapshot_date: may, mrr_cents: 14_000, status: :active)
    # gain = $40 expansion, loss = $50 churn → 0.8

    assert_equal 0.8, quick_ratio_widget[:data]["2026-05"]
  end

  # --- customer_concentration_widget --------------------------------------

  test "customer_concentration_widget returns top 10 by active MRR with %" do
    big   = create(:customer, name: "Big",   anonymized_label: "Big Co")
    small = create(:customer, name: "Small")
    create(:subscription, customer: big,   mrr_cents: 80_000, status: :active)
    create(:subscription, customer: small, mrr_cents: 20_000, status: :active)
    create(:subscription, customer: small, mrr_cents:  5_000, status: :canceled)  # ignored

    w = customer_concentration_widget
    assert_equal 1000, w[:total_dollars]
    big_row = w[:rows].find { |r| r[:label] == "Big Co" }
    assert_equal 80,   big_row[:percentage]
    assert_equal 800,  big_row[:dollars]
  end

  test "customer_concentration_widget is empty when no active subs exist" do
    create(:customer)
    w = customer_concentration_widget
    assert_empty w[:rows]
  end

  # --- cohort_retention_widget --------------------------------------------

  test "cohort_retention_widget builds one series per cohort with retention %" do
    travel_to Date.new(2026, 5, 15) do
      # Cohort: Mar 2026 = 4 customers, 1 churned in April, 2 churned in May
      mar = Date.new(2026, 3, 10)
      4.times { create(:customer, created_at: mar) }
      Customer.first.update!(churned_on: Date.new(2026, 4, 5))
      Customer.second.update!(churned_on: Date.new(2026, 5, 5))
      Customer.third.update!(churned_on: Date.new(2026, 5, 6))

      w = cohort_retention_widget(cohorts: 1)
      assert_equal 1, w[:data].size

      curve = w[:data].first[:data]
      assert_equal 100.0, curve["0"]   # all 4 retained at acquisition
      assert_equal 75.0,  curve["1"]   # 1 churned in April → 3/4
      assert_equal 25.0,  curve["2"]   # 3 churned by start of May → 1/4
    end
  end

  test "cohort_retention_widget returns empty data when no customers exist" do
    w = cohort_retention_widget
    assert_empty w[:data]
  end
end
