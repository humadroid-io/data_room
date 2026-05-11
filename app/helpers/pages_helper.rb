module PagesHelper
  # [WIDGET_NAME] or [WIDGET_NAME:argument]. Argument is a snake_case key.
  WIDGET_RE = /\[([A-Z_]+)(?::([a-z][a-z0-9_]*))?\]/

  def render_page_body(page, investor)
    page.body.to_s.gsub(WIDGET_RE) do
      name = Regexp.last_match(1)
      arg  = Regexp.last_match(2)

      case name
      when "CHILD_PAGES"        then render_children_list(page, investor, cols: 1)
      when "CHILD_PAGES_2_COL"  then render_children_list(page, investor, cols: 2)
      when "CUSTOMER_PIPELINE"  then render(partial: "pages/widgets/customer_pipeline", locals: { attribute_key: arg })
      when "MONTHLY_REVENUE"    then render(partial: "pages/widgets/monthly_revenue")
      when "RETENTION_COHORT"   then render(partial: "pages/widgets/retention_cohort",  locals: { attribute_key: arg })
      when "CHURNED_CUSTOMERS"  then render(partial: "pages/widgets/churned_customers")
      when "CHURN_REASONS"      then render(partial: "pages/widgets/churn_reasons")
      when "CHURN_RATE"         then render(partial: "pages/widgets/churn_rate")
      when "MRR_WALK"           then render(partial: "pages/widgets/mrr_walk")
      when "NRR_GRR"            then render(partial: "pages/widgets/nrr_grr")
      when "QUICK_RATIO"        then render(partial: "pages/widgets/quick_ratio")
      when "CUSTOMER_CONCENTRATION" then render(partial: "pages/widgets/customer_concentration")
      when "COHORT_RETENTION"   then render(partial: "pages/widgets/cohort_retention")
      else Regexp.last_match(0) # leave unknown tokens visible as authoring hint
      end
    end.html_safe
  end

  # SQLite returns the month bucket as `'YYYY-MM'`; Postgres would use
  # `to_char(paid_at, 'YYYY-MM')`. Centralized here so chart helpers don't
  # carry adapter knowledge.
  def month_bucket_sql
    Arel.sql("strftime('%Y-%m', paid_at)")
  end

  def render_children_list(page, investor, cols:)
    children = page.visible_children_for(investor)
    render(partial: "pages/widgets/children_list",
           locals:  { children: children, cols: cols })
  end

  # Returns chartkick-ready data for a stacked-area "revenue per month per
  # product" chart. Reads from the Payment table (actual cash collected,
  # post-discount) in **USD** — non-USD amounts are converted via the fixed
  # rates in CurrencyConverter at write time.
  def monthly_revenue_chart_data
    raw = Payment
      .left_outer_joins(:subscription)
      .group(month_bucket_sql, "subscriptions.product_code", "subscriptions.stripe_price_id")
      .sum(:amount_cents_usd)

    by_label = Hash.new { |h, k| h[k] = {} }
    raw.each do |(month, product_code, price_id), cents|
      label = product_code.presence || price_id.presence || "Other"
      by_label[label][month] = (by_label[label][month] || 0) + (cents / 100)
    end

    by_label
      .sort_by { |label, _| label }
      .map { |label, points| { name: label.titleize, data: points } }
  end

  # Builds the [RETENTION_COHORT] chart data — distinct customers per snapshot
  # date, grouped by a captured single-select Customer attribute. `attribute_key`
  # is the explicit widget arg; defaults to the first matching attribute.
  def retention_cohort_widget(attribute_key)
    key = attribute_key.presence ||
          AttributeDefinition.for_resource(Customer)
                             .captured.where(data_type: :single_select)
                             .first&.key
    return { key: nil } unless key

    json_path = "$.#{Customer.sanitize_json_key(key)}"
    raw = Snapshot
      .joins(:subscription)
      .where("json_extract(captured_attributes, ?) IS NOT NULL", json_path)
      .group(:snapshot_date)
      .group(Arel.sql("json_extract(captured_attributes, '#{json_path}')"))
      .distinct
      .count("subscriptions.customer_id")

    by_value = Hash.new { |h, k| h[k] = {} }
    raw.each do |(date, value), count|
      by_value[value][date] = count
    end

    {
      key:      key,
      chart_id: "retention-cohort-#{SecureRandom.hex(4)}",
      data: by_value
              .sort_by { |value, _| value.to_s }
              .map { |value, points| { name: value.to_s.titleize, data: points } },
      library: {
        plugins: {
          legend: { position: "bottom" },
          zoom:   chart_zoom_options
        }
      }
    }
  end

  # ----- MRR movements (foundation for walk / NRR / quick ratio) -----------

  # Per-month dollar movements derived from monthly Snapshots:
  #   { "YYYY-MM" => { start_mrr:, new:, expansion:, contraction:, churn: } }
  # All values are dollars (positive integers). Snapshots are the source of
  # truth; if MonthlySnapshotJob hasn't run for enough months, returns
  # whatever buckets do have data (or {} when fewer than 2 are available).
  def mrr_movements(months_back: 12)
    months = monthly_buckets(months_back)
    return {} if months.size < 2

    by_month = customer_mrr_by_month(months)

    # Pair each month with its successor; label by the EARLIER one. So the
    # "2026-05" bucket = May 1 → June 1 = changes that happened during May.
    # The latest bucket (current month) compares to "next month start" which
    # uses live subscription state since no snapshot exists for it yet.
    months.each_cons(2).each_with_object({}) do |(month, next_month), acc|
      acc[month.strftime("%Y-%m")] = movements_between(by_month[month] || {}, by_month[next_month] || {})
    end
  end

  # ----- Investor MRR widgets ----------------------------------------------

  def mrr_walk_widget
    movements = mrr_movements
    {
      data: [
        { name: "New",         data: movements.transform_values { |m|  m[:new] } },
        { name: "Expansion",   data: movements.transform_values { |m|  m[:expansion] } },
        { name: "Contraction", data: movements.transform_values { |m| -m[:contraction] } },
        { name: "Churn",       data: movements.transform_values { |m| -m[:churn] } }
      ],
      chart_id: "mrr-walk-#{SecureRandom.hex(4)}",
      colors:   [ "#16a34a", "#86efac", "#f97316", "#dc2626" ],
      library:  { plugins: { legend: { position: "bottom" }, zoom: chart_zoom_options } }
    }
  end

  def nrr_grr_widget
    movements = mrr_movements
    nrr = {}
    grr = {}
    movements.each do |month, m|
      next if m[:start_mrr].zero?
      nrr[month] = ((m[:start_mrr] + m[:expansion] - m[:contraction] - m[:churn]).to_f / m[:start_mrr] * 100).round(1)
      grr[month] = ((m[:start_mrr] - m[:contraction] - m[:churn]).to_f / m[:start_mrr] * 100).round(1)
    end
    {
      data:     [ { name: "NRR", data: nrr }, { name: "GRR", data: grr } ],
      chart_id: "nrr-grr-#{SecureRandom.hex(4)}",
      colors:   [ "#2563eb", "#94a3b8" ],
      library:  { plugins: { legend: { position: "bottom" }, zoom: chart_zoom_options } }
    }
  end

  def quick_ratio_widget
    movements = mrr_movements
    series = movements.transform_values do |m|
      loss = m[:contraction] + m[:churn]
      loss.zero? ? nil : ((m[:new] + m[:expansion]).to_f / loss).round(2)
    end.compact
    {
      data:     series,
      chart_id: "quick-ratio-#{SecureRandom.hex(4)}",
      colors:   [ "#7c3aed" ],
      library:  { plugins: { legend: { display: false }, zoom: chart_zoom_options } }
    }
  end

  def customer_concentration_widget
    rows = active_mrr_per_customer
    total = rows.sum { |r| r[:mrr_cents] }
    return { rows: [], total: 0 } if total.zero?

    top = rows.sort_by { |r| -r[:mrr_cents] }.first(10).map do |r|
      r.merge(percentage: (r[:mrr_cents].to_f / total * 100).round(1),
              dollars:    r[:mrr_cents] / 100)
    end
    { rows: top, total_dollars: total / 100 }
  end

  def cohort_retention_widget(cohorts: 12)
    cohort_months = recent_cohort_months(cohorts)
    return { data: [] } if cohort_months.empty?

    series = cohort_months.map do |cohort|
      { name: cohort.strftime("%b %Y"), data: retention_curve_for(cohort) }
    end.reject { |s| s[:data].empty? }

    {
      data:     series,
      chart_id: "cohort-retention-#{SecureRandom.hex(4)}",
      library:  { plugins: { legend: { position: "bottom" }, zoom: chart_zoom_options } }
    }
  end

  # ----- Churn widgets ------------------------------------------------------

  # [CHURNED_CUSTOMERS] — list of churned customers with date and reason.
  # Investors see anonymized labels (or names if no anonymization); admins
  # browsing directly see the same view (intentional — what's shown to
  # investors is the source of truth).
  def churned_customers_widget
    Customer.churned.order(churned_on: :desc).map do |c|
      {
        label:         c.anonymized_label.presence || c.name,
        churned_on:    c.churned_on,
        category:      c.churn_reason_category,
        category_text: c.churn_reason_category&.titleize,
        notes:         c.churn_reason_notes
      }
    end
  end

  # [CHURN_REASONS] — counts by reason category, sorted descending.
  def churn_reasons_breakdown
    counts = Customer.churned.where.not(churn_reason_category: nil).group(:churn_reason_category).count
    counts.transform_keys! { |k| Customer.churn_reason_categories.key(k) || k.to_s }
    counts.sort_by { |_, n| -n }.to_h
  end

  # [CHURN_RATE] — for each month, the % of customers active at the start of
  # the month who churned during it. Returns "YYYY-MM" => percent.
  #
  # Derived from Subscription.started_at / canceled_at (Stripe's authoritative
  # dates), not Customer.created_at — so customers imported recently still
  # contribute correctly to historical months. A customer is "active at
  # boundary B" iff they have any subscription with started_at ≤ B AND
  # (canceled_at IS NULL OR > B). "Churned in month M" means active at the
  # start of M but not at the start of M+1.
  def monthly_churn_rate(months_back: 12)
    end_month   = Date.current.beginning_of_month
    start_month = end_month - months_back.months
    boundaries  = (0..(months_back + 1)).map { |i| start_month + i.months }

    subs = Subscription.pluck(:customer_id, :started_at, :canceled_at)
    active_sets = boundaries.each_with_object({}) do |b, h|
      h[b] = active_customer_ids_at(subs, b)
    end

    boundaries.each_cons(2).each_with_object({}) do |(month_start, next_start), acc|
      bucket = month_start.strftime("%Y-%m")
      start_set = active_sets[month_start]

      next acc[bucket] = 0.0 if start_set.empty?

      end_set = active_sets[next_start]
      churned = start_set - end_set
      acc[bucket] = (churned.size.to_f / start_set.size * 100).round(2)
    end
  end

  # Returns a Set of customer_ids that had at least one active subscription
  # at the given boundary timestamp. `subs` is a pre-fetched array of
  # [customer_id, started_at, canceled_at] tuples.
  def active_customer_ids_at(subs, boundary)
    ids = Set.new
    subs.each do |customer_id, started_at, canceled_at|
      next unless started_at && started_at <= boundary
      next if canceled_at && canceled_at <= boundary
      ids << customer_id
    end
    ids
  end

  def churn_rate_chart_id
    @churn_rate_chart_id ||= "churn-rate-#{SecureRandom.hex(4)}"
  end

  def churn_rate_widget
    {
      data:     monthly_churn_rate.map { |month, pct| [ month, pct ] },
      chart_id: churn_rate_chart_id,
      library: {
        plugins: {
          legend: { display: false },
          zoom:   chart_zoom_options
        },
        scales: { y: { ticks: { callback: nil } } } # chartkick handles % via suffix
      }
    }
  end

  # Bundles everything the [MONTHLY_REVENUE] partial needs into one struct
  # so the ERB stays declarative.
  def monthly_revenue_widget
    events = Event.chronological.to_a
    {
      data:        monthly_revenue_chart_data,
      events:      events,
      chart_id:    "monthly-revenue-#{SecureRandom.hex(4)}",
      library: {
        plugins: {
          legend:     { position: "bottom" },
          annotation: { annotations: chart_event_annotations(events) },
          zoom:       chart_zoom_options
        }
      }
    }
  end

  # Default Chart.js zoom-plugin config: scroll wheel zooms (with ctrl
  # required so page scroll still works), drag pans, double-click resets.
  # Locked to the x-axis only — vertical squish on time-series is just noise.
  def chart_zoom_options
    {
      pan:  { enabled: true, mode: "x" },
      zoom: {
        wheel: { enabled: true, modifierKey: "ctrl", speed: 0.05 },
        pinch: { enabled: true },
        drag:  { enabled: true, backgroundColor: "rgba(0,0,0,0.04)", borderColor: "rgba(0,0,0,0.2)", borderWidth: 1 },
        mode:  "x"
      },
      limits: { x: { minRange: 1 } }
    }
  end

  # Returns Chart.js annotation config (one vertical line per Event) keyed by a
  # stable id. Pass into chartkick's library: { plugins: { annotation: {...} } }.
  # Lines anchor on the event's month bucket so they line up with the chart's
  # categorical x-axis.
  def chart_event_annotations(events)
    Array(events).each_with_object({}) do |event, acc|
      acc["event_#{event.id}"] = {
        type: "line",
        xMin: event.month_bucket,
        xMax: event.month_bucket,
        borderColor: event.color,
        borderWidth: 1.5,
        borderDash: [ 4, 4 ],
        label: {
          content: event.title,
          display: true,
          position: "start",
          backgroundColor: event.color,
          color: "#fff",
          font: { size: 10, weight: "500" },
          padding: { top: 2, bottom: 2, left: 4, right: 4 },
          borderRadius: 2
        }
      }
    end
  end

  def page_visibility_badge(page)
    case page.visibility
    when "draft"
      content_tag(:span, "Draft", class: "badge badge-ghost badge-sm")
    when "public"
      content_tag(:span, "Published", class: "badge badge-success badge-sm")
    when "private"
      count = page.page_accesses.count
      content_tag(:span, "Private · #{count}", class: "badge badge-warning badge-sm")
    end
  end

  # ----- Support: snapshot-based MRR aggregation ---------------------------

  # Monthly first-of-month boundaries spanning the trailing window plus
  # one boundary into the future (so the current month gets a forward
  # comparison). For today=May 15, months_back=12 returns 14 boundaries
  # from May 2025 through June 2026. Pairs of consecutive boundaries form
  # the labeled buckets — see mrr_movements.
  def monthly_buckets(months_back)
    end_month = Date.current.beginning_of_month
    (-(months_back)..1).map { |i| end_month + i.months }
  end

  # { Date => { customer_id => total_mrr_cents } } for the given months.
  # Prefers Snapshot data when available (precise historical MRR), falls
  # back to deriving from Subscription dates + current mrr_cents when not
  # — so revenue widgets work without a backfill of snapshots.
  def customer_mrr_by_month(months)
    snapshot_months = Snapshot.where(snapshot_date: months).distinct.pluck(:snapshot_date).to_set

    months.each_with_object({}) do |month, acc|
      acc[month] = if snapshot_months.include?(month)
        mrr_from_snapshots(month)
      else
        mrr_from_subscriptions(month)
      end
    end
  end

  # Snapshot-based: precise. Only counts active/trialing rows. USD.
  def mrr_from_snapshots(month)
    Snapshot
      .joins(:subscription)
      .where(snapshot_date: month,
             status: [ Snapshot.statuses[:active], Snapshot.statuses[:trialing] ])
      .group("subscriptions.customer_id")
      .sum(:mrr_cents_usd)
  end

  # Subscription-based effective MRR per customer AT the given boundary
  # (first-of-month timestamp). A sub counts toward MRR at that moment iff
  # started_at <= boundary AND (canceled_at IS NULL OR canceled_at > boundary).
  # The strict `> boundary` matters: a sub canceled May 31 is active at the
  # May 1 boundary but NOT at the June 1 boundary, so the difference between
  # the two boundaries surfaces as churn in the May bucket. USD.
  def mrr_from_subscriptions(boundary)
    result = Hash.new(0)
    Subscription
      .where("started_at <= ?", boundary)
      .where("canceled_at IS NULL OR canceled_at > ?", boundary)
      .find_each do |sub|
      result[sub.customer_id] += sub.effective_mrr_cents_usd(as_of: boundary)
    end
    result
  end

  # Compares two { customer_id => cents } maps and returns the dollar
  # movements between them.
  def movements_between(prev_map, now_map)
    new_cents         = 0
    expansion_cents   = 0
    contraction_cents = 0
    churn_cents       = 0

    (prev_map.keys | now_map.keys).each do |cid|
      prev_cents = prev_map[cid] || 0
      now_cents  = now_map[cid]  || 0

      if prev_cents.zero?  && now_cents.positive?
        new_cents += now_cents
      elsif prev_cents.positive? && now_cents.zero?
        churn_cents += prev_cents
      elsif now_cents > prev_cents
        expansion_cents += (now_cents - prev_cents)
      elsif now_cents < prev_cents
        contraction_cents += (prev_cents - now_cents)
      end
    end

    {
      start_mrr:   prev_map.values.sum / 100,
      new:         new_cents / 100,
      expansion:   expansion_cents / 100,
      contraction: contraction_cents / 100,
      churn:       churn_cents / 100
    }
  end

  # ----- Support: customer concentration -----------------------------------

  def active_mrr_per_customer
    rows = Customer
      .joins(:subscriptions)
      .where(subscriptions: { status: [ Subscription.statuses[:active], Subscription.statuses[:trialing] ] })
      .group("customers.id", "customers.name", "customers.anonymized_label")
      .sum("subscriptions.mrr_cents_usd")

    rows.map do |(id, name, anon), cents|
      { id: id, label: anon.presence || name, mrr_cents: cents }
    end
  end

  # ----- Support: cohort retention -----------------------------------------

  # Returns Date objects for the first-of-month of the N most-recent
  # cohorts (by customer creation date). Empty if no customers exist.
  def recent_cohort_months(limit)
    Customer
      .where.not(created_at: nil)
      .pluck(Arel.sql("strftime('%Y-%m', created_at)"))
      .uniq
      .sort
      .last(limit)
      .map { |bucket| Date.strptime("#{bucket}-01", "%Y-%m-%d") }
  end

  # For a given cohort month, returns { "N" => percent retained }.
  # "Retained at month N" = the customer hadn't churned by the END of month N
  # (still on the books N full months after acquisition). Month 0 is the
  # acquisition month — everyone is at 100% there unless they signed up and
  # churned in the same month.
  def retention_curve_for(cohort)
    cohort_customers = Customer
      .where(created_at: cohort.beginning_of_month..cohort.end_of_month)
      .pluck(:id, :churned_on)
    return {} if cohort_customers.empty?

    cohort_size = cohort_customers.size
    end_month   = Date.current.beginning_of_month
    months_span = ((end_month.year - cohort.year) * 12) + (end_month.month - cohort.month)

    (0..months_span).each_with_object({}) do |n, acc|
      probe_end = cohort + (n + 1).months  # start of the month AFTER probe
      retained  = cohort_customers.count { |_, churned_on| churned_on.nil? || churned_on >= probe_end }
      acc[n.to_s] = (retained.to_f / cohort_size * 100).round(1)
    end
  end
end
