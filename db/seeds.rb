# Idempotent seeds. Builds a full demo page tree showcasing every widget
# token, plus an admin user and a demo investor.

require_relative "seeds/customer_attributes"

# --- Users ----------------------------------------------------------------

admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.name     = "Admin"
  u.password = "password123"
  u.role     = :admin
end
admin.regenerate_api_token! if admin.api_token.blank?

demo_investor = Investor.find_or_create_by!(email: "investor@example.com") do |i|
  i.name             = "Demo Investor"
  i.fund_name        = "Demo Fund"
  i.watermark_label  = "Demo Investor"
  i.access_code      = "demo-investor-2026"
  i.active           = true
end

# --- Page tree ------------------------------------------------------------
#
# Each entry: path, title, tldr, body. body=nil means CHILD_PAGES default.
# parent inferred from the path prefix; ordered by appearance.

PAGES = [
  { path: "/", title: "Welcome", tldr: "Self-hosted investor data room. Use the sidebar to navigate.",
    body: <<~HTML },
      <p>Welcome. This data room is organized by section. Use the navigation
      below or in the sidebar to dive in.</p>
      <p>[CHILD_PAGES_2_COL]</p>
    HTML

  # ------- Company ------------------------------------------------------
  { path: "/company", title: "Company", tldr: "Who we are." },
  { path: "/company/about", title: "About",
    tldr: "Background, mission, traction.",
    body: <<~HTML },
      <p>Replace this with your company's story — origin, mission, current stage.</p>
      <h2>Why now</h2>
      <p>Macro tailwinds, market timing, your unique wedge.</p>
    HTML

  # ------- Product ------------------------------------------------------
  { path: "/product", title: "Product", tldr: "What we ship." },
  { path: "/product/overview", title: "Overview",
    tldr: "How it works.",
    body: <<~HTML },
      <p>High-level architecture, target user, value proposition.</p>
      <p>Drop in screenshots, loom recordings, etc. via the editor.</p>
    HTML

  # ------- Customers ----------------------------------------------------
  { path: "/customers", title: "Customers", tldr: "Who's paying us." },
  { path: "/customers/concentration", title: "Concentration",
    tldr: "Top customers as a share of MRR.",
    body: <<~HTML },
      <p>Healthy SaaS keeps any single customer below 25% of MRR — bars below
      turn red when concentration risk crosses that threshold.</p>
      <p>[CUSTOMER_CONCENTRATION]</p>
    HTML
  { path: "/customers/pipeline", title: "Pipeline by stage",
    tldr: "Where customers sit in their lifecycle.",
    body: <<~HTML },
      <p>Customers grouped by the <code>compliance_stage</code> custom attribute.
      Edit attributes under <strong>Admin → Attributes</strong> to add your own.</p>
      <p>[CUSTOMER_PIPELINE:compliance_stage]</p>
    HTML
  { path: "/customers/cohorts", title: "Stage progression",
    tldr: "How customers move through stages over time.",
    body: <<~HTML },
      <p>Distinct customers per snapshot date, grouped by their captured stage.
      Different from logo retention — this shows the <em>journey</em>, not survival.</p>
      <p>[RETENTION_COHORT:compliance_stage]</p>
    HTML

  # ------- Revenue ------------------------------------------------------
  { path: "/revenue", title: "Revenue", tldr: "Cash, MRR, retention." },
  { path: "/revenue/monthly", title: "Monthly revenue",
    tldr: "Real cash collected per month, stacked by product.",
    body: <<~HTML },
      <p>Source: paid Stripe invoices (post-discount, post-coupon). Vertical
      lines mark events from <strong>Admin → Events</strong> so you can correlate
      revenue inflections with what was happening at the company.</p>
      <p>[MONTHLY_REVENUE]</p>
    HTML
  { path: "/revenue/mrr-walk", title: "MRR walk",
    tldr: "New + expansion vs contraction + churn.",
    body: <<~HTML },
      <p>Stacked bars: gains above zero, losses below. Bar net height tells
      you net new MRR for the month — the cleanest growth signal there is.</p>
      <p>[MRR_WALK]</p>
    HTML
  { path: "/revenue/retention", title: "Net + Gross retention",
    tldr: "How much existing-customer revenue we keep month over month.",
    body: <<~HTML },
      <p><strong>NRR</strong> includes expansion; sustained NRR above 100%
      means we'd grow even without acquiring new customers — best-in-class.
      <strong>GRR</strong> excludes expansion and caps at 100%; it's a pure
      churn metric.</p>
      <p>[NRR_GRR]</p>
    HTML
  { path: "/revenue/quick-ratio", title: "Quick ratio",
    tldr: "Gain ÷ loss per month.",
    body: <<~HTML },
      <p>Quick ratio = (new + expansion) ÷ (contraction + churn). Above 4 is
      the conventional bar for healthy early-stage SaaS — every $1 lost is
      replaced with $4+ of new revenue.</p>
      <p>[QUICK_RATIO]</p>
    HTML
  { path: "/revenue/cohorts", title: "Cohort retention",
    tldr: "% of each acquisition cohort still active over time.",
    body: <<~HTML },
      <p>One line per cohort (the month customers were acquired in). X-axis is
      months-since-acquisition. Steep early drops = leaky onboarding;
      flattening tails = sticky core.</p>
      <p>[COHORT_RETENTION]</p>
    HTML

  # ------- Churn --------------------------------------------------------
  { path: "/churn", title: "Churn", tldr: "Who left, when, and why." },
  { path: "/churn/rate", title: "Churn rate",
    tldr: "Monthly logo churn (%) over the trailing 12 months.",
    body: <<~HTML },
      <p>Logo churn = customers churned this month ÷ customers active at the
      start of the month. Trended over the trailing year.</p>
      <p>[CHURN_RATE]</p>
    HTML
  { path: "/churn/reasons", title: "Reasons",
    tldr: "Why customers leave, categorized.",
    body: <<~HTML },
      <p>Aggregated from each churned customer's recorded reason. We capture
      both a category (price, competitor, lack of features, …) and freetext
      notes — the freetext is shown in the log on the next page.</p>
      <p>[CHURN_REASONS]</p>
    HTML
  { path: "/churn/log", title: "Churn log",
    tldr: "Detailed list of every customer who churned, with the reason.",
    body: <<~HTML },
      <p>Anonymized labels are shown to investors when set; otherwise the
      customer name. We're transparent about losses by design.</p>
      <p>[CHURNED_CUSTOMERS]</p>
    HTML

  # ------- Team ---------------------------------------------------------
  { path: "/team", title: "Team",
    tldr: "People behind the work.",
    body: <<~HTML },
      <p>Founders, key hires, advisors. Add a brief bio per row. Use Lexxy
      formatting for headings, links, and lists.</p>
    HTML
].freeze

PAGES.each_with_index do |attrs, i|
  parent_path = attrs[:path] == "/" ? nil : attrs[:path].sub(%r{/[^/]+\z}, "").presence
  parent = parent_path && Page.find_by(path: parent_path == "" ? "/" : parent_path)
  parent = nil if parent&.root_landing?  # top-level sections sit at root, not under /

  slug = attrs[:path] == "/" ? "" : attrs[:path].split("/").last

  page = Page.find_or_initialize_by(path: attrs[:path])
  page.assign_attributes(
    slug:       slug,
    title:      attrs[:title],
    tldr:       attrs[:tldr],
    sort_order: i,
    parent:     parent,
    visibility: :public
  )
  if page.body.body.blank?
    page.body = attrs[:body] || "<p>[CHILD_PAGES]</p>"
  end
  page.save!
end

# --- Demo events (annotate revenue chart) --------------------------------

[
  { occurred_on: 8.months.ago.to_date, kind: :funding,     title: "Pre-seed close" },
  { occurred_on: 5.months.ago.to_date, kind: :launch,      title: "v1.0 GA" },
  { occurred_on: 3.months.ago.to_date, kind: :partnership, title: "Reseller deal signed" },
  { occurred_on: 1.month.ago.to_date,  kind: :hire,        title: "Head of Sales joined" }
].each do |attrs|
  Event.find_or_create_by!(title: attrs[:title]) do |e|
    e.occurred_on = attrs[:occurred_on]
    e.kind        = attrs[:kind]
  end
end

puts "Seeded:"
puts "  admin:        admin@example.com / password123"
puts "  investor:     access code → #{demo_investor.access_code}"
puts "  mcp token:    #{admin.api_token}"
puts "  pages:        #{Page.count}"
puts "  events:       #{Event.count}"
puts "  attrs:        #{AttributeDefinition.count}"
