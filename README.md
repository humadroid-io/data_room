# Data Room

A self-hosted investor data room. Renders hierarchically-organized, password-gated,
watermarked pages; pulls customer + subscription data from Stripe; exposes an admin
UI and an MCP server so an LLM agent can manage content on your behalf.

The app is intentionally generic — domain-specific data lives in custom attributes
and seeds, not core schema. Forking it for a non-investor use case is a config job,
not a refactor.

---

## Stack

| Layer            | Choice                                              |
| ---------------- | --------------------------------------------------- |
| Framework        | Rails 8.1                                           |
| Language         | Ruby 3.4                                            |
| Database         | SQLite (`solid_queue`, `solid_cache`, `solid_cable`) |
| Frontend         | Hotwire (Turbo + Stimulus), no SPA                  |
| Rich text        | Lexxy on top of Action Text                         |
| CSS              | Tailwind v4 + DaisyUI 5 (minimal monochrome theme)  |
| JS bundler       | esbuild (`jsbundling-rails`)                        |
| Charts           | Chartkick + Chart.js                                |
| Stripe           | `stripe` gem, daily sync via Solid Queue recurring  |
| MCP              | `mcp` gem, Streamable HTTP, Bearer-token auth       |
| Testing          | Minitest + factory_bot + shoulda + mocha            |
| Deploy           | Kamal 2 (Dockerfile + `.kamal/`)                    |

---

## Getting started

```bash
bundle install
yarn install
bin/rails db:prepare         # create + migrate + seed
bin/dev                      # web + js + css watchers (Procfile.dev)
```

Open <http://localhost:3000>.

`bin/rails db:seed` prints the credentials and tokens at the end. Defaults:

```
admin:     admin@example.com / password123
investor:  access code → demo-investor-2026
mcp token: dr_…
```

---

## How the app is organized

There are three audiences:

1. **Investor** — signs in with a single access code, browses the public site.
2. **Admin** — full CRUD on pages, customers, investors; can browse the public
   site directly (sees drafts) or impersonate any investor.
3. **LLM agent** — talks to the MCP server with a Bearer token, can read and
   write pages, set per-page visibility, and pull customer/investor data.

### URL surface

| Path                 | Purpose                                                      |
| -------------------- | ------------------------------------------------------------ |
| `/`                  | Investor landing page (root `Page` with `slug = ""`)         |
| `/<any/path>`        | Catch-all to `PagesController#show` (hierarchical lookup)    |
| `/login`             | Investor sign-in (one field: access code). `?code=XXX` prefills |
| `/admin`             | Admin dashboard                                              |
| `/admin/login`       | Admin sign-in (email + password)                             |
| `/mcp`               | MCP Streamable HTTP endpoint (Bearer token)                  |
| `/up`                | Health check                                                 |

### Auth model

Two completely separate sessions, two cookies:

- `cookies.encrypted[:investor_id]` — investor session
- `cookies.encrypted[:admin_user_id]` — admin session

Both can be set at the same time (admin impersonating an investor).
`viewing_as_admin?` means admin-only, no investor cookie.

### Page tree

`Page` is hierarchical with a cached `path`. The single landing page has
`slug = ""` and `path = "/"`; everything else has a slug-derived path.

Renaming a slug or moving a page automatically:
- recomputes the path,
- recomputes descendant paths,
- writes a `PageRedirect` so old bookmarks keep working.

Visibility (single enum, three values):

| `visibility` | Who sees it                          | Allowlist used? |
| ------------ | ------------------------------------ | --------------- |
| `draft`      | Admins only (when browsing directly) | No              |
| `public`     | Any signed-in investor               | No              |
| `private`    | Only investors on the allowlist      | **Yes**         |

`PageAccess` is the allowlist for `private` pages — presence of a row means
"this investor can see this page". `Page.live` returns `public + private`
(everything that isn't a draft). When a page changes from `private` to
anything else, its `PageAccess` rows are wiped automatically.

### Widget tokens (rendered server-side)

Inside a page body you can drop these tokens; `PagesHelper#render_page_body`
replaces them at render time. Two of them accept an optional argument after
`:` to point at a specific custom attribute.

| Token                                | What it renders                                                           |
| ------------------------------------ | ------------------------------------------------------------------------- |
| `[CHILD_PAGES]`                      | Single-column list of visible child pages                                 |
| `[CHILD_PAGES_2_COL]`                | Two-column grid                                                           |
| `[MONTHLY_REVENUE]`                  | Stacked-area chart of cash collected per month (from imported Stripe payments), one band per product |
| `[CUSTOMER_PIPELINE:attribute_key]`  | Table of customers grouped by a single-select Customer attribute          |
| `[RETENTION_COHORT:attribute_key]`   | Stacked area of distinct customers by month, grouped by a captured single-select attribute |
| `[CHURNED_CUSTOMERS]`                | Table of customers who churned (date, anonymized label, reason category, notes) |
| `[CHURN_REASONS]`                    | Bar chart of churn-reason categories, sorted by count                     |
| `[CHURN_RATE]`                       | Monthly logo-churn rate (%) over the trailing 12 months                   |
| `[MRR_WALK]`                         | Stacked column chart: new + expansion above zero, contraction + churn below |
| `[NRR_GRR]`                          | Net and Gross Revenue Retention (%) per month                             |
| `[QUICK_RATIO]`                      | (new + expansion) ÷ (contraction + churn) per month — >4 is healthy SaaS  |
| `[CUSTOMER_CONCENTRATION]`           | Top 10 customers by active MRR with % share; bars ≥25% turn red           |
| `[COHORT_RETENTION]`                 | Last 12 acquisition cohorts as separate retention curves                  |

The pipeline and cohort widgets fall back to the **first** matching
attribute on `Customer` if you omit the argument — useful for poking
around, but always pass the key explicitly in production pages so renames
don't silently change the chart.

Hidden children are filtered out of `[CHILD_PAGES]` automatically — no
extra config.

### Custom attributes (`HasCustomAttributes`)

Customers and Subscriptions both `include HasCustomAttributes`. The schema
for those custom fields lives in `attribute_definitions`:

- `data_type`: string / text / integer / decimal / date / boolean / single_select / multi_select
- `options`: JSON array for select types `[{value, label, color}]`
- `capture_on_snapshot: true` → that key gets frozen into `Snapshot.captured_attributes`
  on the monthly snapshot job, so historical analysis isn't lossy when an
  attribute changes later.

The admin form for Customer renders fields dynamically from `AttributeDefinition.for_resource(Customer)`,
so adding a new field is one row in the `attribute_definitions` table — no schema
change, no controller change.

SQLite JSON1 powers two query helpers:

```ruby
Customer.with_custom_attribute("compliance_stage", "in_audit").count
Customer.with_custom_attribute_containing("frameworks", "soc2")
```

### Stripe sync

`StripeSyncJob` runs daily in production (`config/recurring.yml`). In
development you trigger it manually from **Admin → Dashboard → Sync now**
(or `bin/rails runner 'StripeSyncJob.perform_now'`). The job does three
things in order:

1. **Customers** — imports per the configured mode (`none / all / paying`).
2. **Subscriptions** — upserts each one. Captures both `stripe_price_id`
   (raw) and `product_code` (looked up via the YAML map). Unmapped prices
   leave `product_code` nil; the raw `stripe_price_id` is the display fallback.
3. **Payments** — imports paid Stripe invoices into the `payments` table.
   `amount_cents` is what actually hit your bank (post-discount, post-coupon).
   This is what `[MONTHLY_REVENUE]` charts; nominal MRR from the Subscription
   row is informational only.

Last-sync timestamp + summary (customers / subscriptions / payments) are
cached and shown on the dashboard.

The YAML below is **read on every sync**, not at boot — edit it and click
Sync now without restarting. The products map is **optional**; unmapped
prices show their raw `stripe_price_id` as the product label everywhere
they're displayed.

#### Stripe API key

The initializer (`config/initializers/stripe.rb`) reads the key from
encrypted credentials first, then falls back to `STRIPE_API_KEY` env var:

```ruby
api_key = Rails.application.credentials.dig(:stripe, :api_key) || ENV["STRIPE_API_KEY"]
```

**Production / shared dev (recommended):** Rails encrypted credentials.

```bash
bin/rails credentials:edit
```

Add (or merge):

```yaml
stripe:
  api_key: sk_live_…   # use sk_test_… in development
```

The encrypted file (`config/credentials.yml.enc`) is committed; the
`config/master.key` that decrypts it is `.gitignore`'d. In production, ship
the key as the `RAILS_MASTER_KEY` env var.

**Quick local override:** environment variable.

```bash
export STRIPE_API_KEY=sk_test_…
bin/dev
```

Credentials win when both are present. Restart the app after changing either.

#### Mapping Stripe prices to product codes

Stripe Price IDs (`price_1Ab2Cd3Ef4…`) are opaque, randomly assigned, and
differ across Stripe environments (test vs live, dev vs prod accounts). You
do not want them sprinkled through your app code — that would couple your
charts and queries to whatever Stripe happened to assign.

`config/stripe_products.yml` translates them — once — into stable, semantic
product codes that the rest of the app uses:

```yaml
production:
  customer_import: paying        # none | all | paying
  products:
    price_1Ab2Cd3Ef4: pro
    price_5Gh6Ij7Kl8: pro_discounted
    price_9Mn0Op1Qr2: starter
```

The right-hand side is *your* namespace — pick any snake_case codes that
mean something to your business. It flows through the system like this:

1. **`StripeSyncJob`** sets two columns on each `Subscription`:
   `stripe_price_id` (raw, always populated for synced subs) and
   `product_code` (looked up via the YAML map, **nil** when not mapped).
2. **Display fallback** — `Subscription#display_product` returns
   `product_code → stripe_price_id → "—"`. Add a mapping later, click Sync
   now, and the friendly name lights up everywhere historical, retroactively.
3. **`Subscription` scopes** use the codes:
   ```ruby
   Subscription.for_product("starter")  # WHERE product_code = 'starter'
   Subscription.active_now              # active + trialing
   ```
4. **`[MONTHLY_REVENUE]`** stacks payments by month, attributing each
   payment to its subscription's product (or raw `stripe_price_id` for
   unmapped, or "Other" for one-off payments).
5. **MCP tools** (`list_customers_tool`, etc.) surface revenue by these codes
   to LLM agents.

**Multiple prices → same code** is the common pattern: list-price plus a
discounted variant both map to `pro` so dashboards group them, but the
distinct price IDs let you tell them apart in the raw subscription row.

**Updating it:** when you add or rename a price in Stripe (e.g. switching
from monthly to annual billing for the same product), edit the YAML and
click Sync now — no migration, no code change, no restart. Subscriptions
get re-attributed; payments inherit the new mapping via the join.

**Empty map is fine.** If you don't care about per-product dashboards yet,
leave `products: {}`. Subscriptions display their raw `stripe_price_id`
and `[MONTHLY_REVENUE]` stacks bands by Stripe price ID instead.

#### Customer import modes

`customer_import` (handled by `StripeCustomerImporter`) controls whether
the sync job auto-creates `Customer` rows from Stripe:

- `none` — never auto-create. Admin creates `Customer` rows manually and
  sets `stripe_customer_id` before syncing. Subscriptions for unknown
  customers are logged and skipped.
- `all` — every Stripe customer is upserted into `customers`.
- `paying` — only customers with at least one paid Stripe invoice are
  upserted.

The importer is idempotent and **never overwrites** existing `Customer`
rows — admin edits to name, anonymized label, custom attributes, etc.,
always win. Name fallback for new rows: Stripe `name` → `email` →
`"Stripe Customer cus_…"`.

Subscription sync still skips and logs any subscription whose
`stripe_customer_id` doesn't match a local row (which only happens in
`none` mode if you forgot to create the customer).

`MonthlySnapshotJob` runs daily but no-ops on day ≠ 1. On the 1st it freezes a
row per subscription with current MRR + status + the `capture_on_snapshot`
attributes. Pass `force: true` (e.g. from console) to ignore the day check.

After a sync the job broadcasts on the `data_room` Action Cable channel —
front-end can subscribe to refresh "last updated" stamps.

### MCP server

Mounted at `POST /mcp`, stateless Streamable HTTP, auth via `Authorization: Bearer dr_…`
checked by `TokenAuthMiddleware`. Token lives on `User#api_token`; you can
generate/rotate from the admin dashboard.

Tools exposed:

- `list_pages_tool`, `get_page_tool`, `create_page_tool`, `update_page_tool`, `delete_page_tool`
- `set_page_visibility_tool` (grant/revoke a single investor on a private page; use `update_page_tool` to flip the page between draft/public/private)
- `list_investors_tool`, `list_customers_tool`

All tools live in `app/mcp/`, all inherit `ApplicationTool` (helpers: `text`,
`json`, `error`, `page_summary`).

Smoke test:

```bash
TOKEN=$(bin/rails runner 'print User.find_by(email: "admin@example.com").api_token')

curl -s http://localhost:3000/mcp \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Wire into Claude Code via your MCP config pointing at `/mcp` with the Bearer header.

---

## Investor-facing UX

- Single-field sign-in. `?code=XXX` prefills.
- Sign-in writes `last_login_at`; every page view writes a `PageView` row.
- Diagonal watermark with `Investor#watermark_label` overlays every page.
- Hidden/draft pages are 404; never disclosed in sidebar or `[CHILD_PAGES]`.

## Admin UX

- **Dashboard:** counts, MRR, recent views, MCP token panel, Stripe sync state.
- **Pages:** Lexxy editor, parent picker, sort order, visibility radio (draft/public/private)
  with allowlist multi-select, document upload, automatic redirects on rename.
- **Customers:** dynamic custom-attributes form built from `AttributeDefinition`s.
  Show page lists subscriptions and recent payments with totals.
- **Subscriptions:** manual entry + Stripe-synced rows. Form exposes both raw
  `stripe_price_id` and the optional friendly `product_code`.
- **Payments:** read-only index of imported Stripe invoices (most-recent 100,
  with totals + currency-aware amounts). Per-customer slice on the customer
  show page. One-off payments without a subscription show as "one-off".
- **Investors:**
  - Index shows view counts.
  - Show page: full stats (total views, distinct pages, per-page table, recent
    activity timeline, allowlisted private pages).
  - Edit page: access code + shareable URL + regenerate button.
- **Users:** admins/viewers, role toggle, password change, MCP token rotation
  (per-user). Self-delete and last-admin demotion are blocked.
- **Events:** company milestones (funding / launch / hire / partnership /
  milestone / risk / other). Each has a date, title, optional description,
  and a kind that color-codes it. Events render as vertical annotation lines
  (with title labels) on the `[MONTHLY_REVENUE]` chart so investors can
  correlate revenue inflections with what was happening at the company,
  plus a legend strip below the chart.
- **Attribute Definitions:** schema editor for custom fields.
- **Page Views:** raw activity log + top-pages and per-investor aggregations.

### Two ways admin can browse the public site

1. **Direct browse** — admin signed in but no investor cookie. Sees drafts and
   pages hidden from everyone. No view tracking. A toolbar across the top of
   every page exposes: Dashboard / Edit page / Page settings / + Sub-page /
   View as ▾ (impersonation dropdown) / Sign out admin.
2. **Impersonation** — pick an investor from the toolbar dropdown or Investors
   index. Sets the investor cookie too; you see exactly what they see (visibility,
   watermark, view tracking writes against their account). Yellow banner with
   **Stop viewing** clears it.

---

## Data model

```
users                    # admins; api_token for MCP
investors                # access_code (unique), watermark_label, expires_at
pages                    # hierarchical; rich-text body; cached path
page_accesses            # allowlist row per (private page, investor)
page_redirects           # old_path -> page_id; populated on slug/parent change
page_views               # one row per investor view
attribute_definitions    # custom-fields schema (polymorphic)
customers                # name + custom_attributes JSON; stripe_customer_id
subscriptions            # Stripe-mirrored; stripe_price_id (raw) + product_code (mapped)
payments                 # one row per paid Stripe invoice (actual cash)
events                   # company milestones, drawn as annotations on time-series charts
snapshots                # monthly time-series of subscription state
                         # action_text_rich_texts (Lexxy/ActionText)
                         # active_storage_* (page documents)
```

Run `bin/rails db:schema:dump` then read `db/schema.rb` for the authoritative shape.

---

## Tests

```bash
bin/rails test                    # full suite (~170 tests)
bin/rails test test/models        # model layer only
bin/rails test test/mcp           # MCP tools + middleware
bin/rails test test/integration   # MCP HTTP round-trip
```

Stack: minitest + factory_bot + shoulda-matchers + shoulda-context + mocha.
No fixtures, no rspec, no minitest mocking. Factories live in `test/factories/`,
the test helper monkey-patches `Rails::TestUnitReporter#format_rerun_snippet`
to fix a shoulda-context 2.0.0 / Rails 8.1 incompatibility.

---

## Deployment notes

- `Dockerfile` builds the production image; `bin/thrust` fronts Puma.
- Kamal config in `.kamal/`; Litestream sidecar recommended for SQLite backup
  to S3 / R2 / B2.
- Solid Queue runs in-process by default (`config/queue.yml`). For higher
  throughput, run a separate `bin/jobs` process.
- Recurring tasks (`config/recurring.yml`) only fire in production by default.
  In development, trigger them manually: `StripeSyncJob.perform_now`,
  `MonthlySnapshotJob.perform_now(force: true)`.

---

## Investor metrics, deeper notes

Most investor-grade SaaS metrics depend on the `snapshots` table —
`MonthlySnapshotJob` freezes each subscription's MRR + status on the 1st
of every month. In production it runs nightly (no-op except day 1). In
development, run it manually to seed history:

```ruby
travel_to(Date.new(2026, 1, 1)) { MonthlySnapshotJob.perform_now(force: true) }
travel_to(Date.new(2026, 2, 1)) { MonthlySnapshotJob.perform_now(force: true) }
# … etc
```

Quick reference for the metric definitions used in widgets:

| Metric | Definition | Healthy zone |
|---|---|---|
| MRR walk | `new + expansion − contraction − churn = net new MRR` | trending up |
| NRR | `(start + expansion − contraction − churn) ÷ start` | ≥100% (best-in-class >120%) |
| GRR | `(start − contraction − churn) ÷ start` | ≥90% |
| Quick ratio | `(new + expansion) ÷ (contraction + churn)` | ≥4 (early-stage), ≥2 (mature) |
| Customer concentration | top customer's share of MRR | <25% |
| Cohort retention | % of cohort still active N months later | flat tail = stickier customers |

`[RETENTION_COHORT:attribute_key]` (stage progression) and
`[COHORT_RETENTION]` (classical acquisition cohort retention) are different
charts — keep both if you want investors to see both lenses.

---

## Reference docs

- Original product spec: [`data-room-mvp-spec.md`](./data-room-mvp-spec.md) (v2 consolidated)
- Future-session instructions: [`CLAUDE.md`](./CLAUDE.md)
