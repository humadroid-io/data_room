# CLAUDE.md

Instructions for Claude Code sessions working on this repo. Read [`README.md`](./README.md)
first for the product/architecture overview — this file is about how to **work**
on the codebase, not what it does.

---

## Stack snapshot

Rails 8.1 · Ruby 3.4 · SQLite (Solid Queue/Cache/Cable) · Hotwire · Lexxy
(ActionText) · Tailwind v4 + DaisyUI 5 · esbuild · Chartkick · Stripe ·
`mcp` gem.

---

## Working preferences

### Tests

- **Minitest only.** No RSpec.
- **factory_bot** for test data. **No fixtures.** If you create a new model,
  add a factory in `test/factories/`.
- **shoulda-matchers + shoulda-context** for the `should …` macros.
- **mocha** for stubbing/mocking. **No `Minitest::Mock`.**
- For models with auto-defaulting attributes (e.g. `Investor#access_code` is
  generated in `before_validation`), don't use `validate_presence_of` — it'll
  fail because the default kicks in. Test the auto-default explicitly.
- For shoulda-matchers' `validate_uniqueness_of`, define `subject { build(:foo) }`
  in the test class so NOT NULL columns are populated.
- Tests run with `parallelize(workers: 1)` because shoulda-context 2.0.0's
  reporter monkey-patch breaks Rails 8.1 parallelism. The workaround is in
  `test/test_helper.rb` — leave it.

### Running tests

```bash
bin/rails test                          # all
bin/rails test test/models              # subset
bin/rails test test/mcp                 # MCP layer
bin/rails test test/integration/foo_test.rb:42   # single test
```

Always run the full suite before declaring work done.

### Don't run the dev server during a session

Don't `bin/dev` or `bin/rails server` — the user keeps it running themselves.
Verify behavior via tests, not curl. If you need to check routing/loading,
`bin/rails routes` and `bin/rails runner '…'` are fine.

### UI / styling

- Tailwind v4 + DaisyUI 5. The DaisyUI theme is a custom minimal monochrome
  configured in `app/assets/stylesheets/application.tailwind.css`. Don't add
  emojis, gradients, drop-shadows, or noise — the aesthetic target is
  Anthropic / Stripe / OpenAI.
- Use semantic DaisyUI classes (`btn`, `card`, `input`, `badge`) with
  `btn-ghost`/`btn-sm`/`badge-soft` for understated controls.
- `prose-page` is the typography wrapper used for rendered Lexxy content.
- The investor watermark element is `.watermark` and only renders when an
  investor session is active.

### Rails patterns to follow

- **Skinny controllers, fat models.** Push behavior into the model or a
  service object. The MCP tool layer (`app/mcp/`) deliberately stays thin
  and delegates to AR.
- **Strong params.** Always. Don't reach into `params` directly in models.
- **`has_rich_text :body`** — Lexxy overrides Trix automatically.
  `f.rich_text_area :body` renders the Lexxy editor.
- **Routes are RESTful.** Custom verbs go on `member` or `collection` blocks.
  Top-level non-CRUD routes (like `regenerate_token`) are explicit `post`/
  `delete` lines.
- **Two separate auth flows** — investor and admin live in parallel cookies.
  Don't try to unify them.
- **No `Time.now`** — use `Time.current` so tests can `travel_to`.

### Files you'll touch a lot

| Purpose                    | Path                                                |
| -------------------------- | --------------------------------------------------- |
| Routes                     | `config/routes.rb`                                  |
| Investor layout + chrome   | `app/views/layouts/investor.html.erb`               |
| Admin layout               | `app/views/layouts/admin.html.erb`                  |
| Auth helpers               | `app/controllers/application_controller.rb`         |
| Custom-attrs concern       | `app/models/concerns/has_custom_attributes.rb`      |
| Page rendering / widgets   | `app/helpers/pages_helper.rb` + `app/views/pages/widgets/` |
| Custom-attribute UI helper | `app/helpers/custom_attributes_helper.rb`           |
| MCP tools                  | `app/mcp/*_tool.rb`                                 |
| MCP server wiring          | `app/mcp/data_room_mcp_server.rb`                   |
| MCP auth                   | `app/mcp/token_auth_middleware.rb`                  |
| Stripe sync                | `app/jobs/stripe_sync_job.rb`                       |
| Stripe customer import     | `app/services/stripe_customer_importer.rb`          |
| Stripe config reader (live-reloads YAML) | `app/services/stripe_config.rb`       |
| Stripe sync trigger (admin) | `app/controllers/admin/stripe_syncs_controller.rb` |
| Recurring schedule         | `config/recurring.yml`                              |
| Stripe config YAML         | `config/stripe_products.yml`                        |
| Seeds                      | `db/seeds.rb` + `db/seeds/customer_attributes.rb`   |

### Adding a new MCP tool

1. Create `app/mcp/your_tool.rb` inheriting `ApplicationTool`. Top-level
   constant — `app/mcp/` is autoloaded **flat** (no `tools/` subdir, no
   namespace). Naming collision with global names (`Server`, `Page`, etc.)
   will break things.
2. Use `description "…"` and `input_schema(properties: {…}, required: […])`.
   **Don't pass `required: []`** — the JSON-schema validator rejects an
   empty array. Omit the key when there are no required args.
3. Implement `def self.call(**, server_context:)` returning either
   `json(payload)`, `text("…")`, or `error("…")`.
4. Register the class in `DataRoomMcpServer::TOOLS`.
5. Add a unit test in `test/mcp/mcp_tools_test.rb` and (if its behavior is
   non-trivial) an integration test in `test/integration/mcp_endpoint_test.rb`.
6. The transport runs **stateless** (`stateless: true`); don't rely on session
   state between calls.

### Adding a new page widget

1. The token grammar is `[NAME]` or `[NAME:argument]`. `WIDGET_RE` already
   captures both — your `when` branch in `render_page_body` receives the
   captured argument as `arg` (or `nil`).
2. Add a `when "MY_WIDGET"` branch in `render_page_body`. If it takes an
   arg, pass it to the partial via `locals: { attribute_key: arg }` (or
   whatever you call it).
3. Create `app/views/pages/widgets/_my_widget.html.erb`. Wrap content in
   `class="not-prose"` if it's HTML that shouldn't inherit prose typography.
4. **Stay domain-agnostic.** Don't hardcode product names, attribute keys,
   or business concepts. Either auto-discover (e.g. group by every distinct
   `product_code`) or accept the key as a widget argument with a sensible
   "first matching attribute" fallback.
5. Add a helper test in `test/helpers/pages_helper_test.rb`.

### Adding a new custom attribute

If it's something the user wants once, edit `db/seeds/customer_attributes.rb`
and reseed. If they want it admin-managed at runtime, do nothing — the admin UI
already supports it.

### Adding a new model

1. Migration with explicit indexes and FK constraints.
2. Model with associations, validations, scopes (in that order).
3. Factory in `test/factories/`.
4. Test in `test/models/` — start with shoulda associations/validations,
   then per-behavior tests.
5. If admin UI is needed: controller in `app/controllers/admin/`, views, and
   a route line in the `namespace :admin` block.

---

## Risk-conscious actions

- **Migrations:** SQLite is fine in dev. For production, the `change_column_*`
  helpers in Rails 8 are safe on SQLite. Don't author destructive
  multi-statement migrations without splitting them into reversible blocks.
- **Tokens/secrets in seeds:** the demo `mcp token` and investor `access_code`
  print to stdout from `db/seeds.rb`. Don't move them to fixtures or commit
  real production tokens.
- **Identifiable data:** seeds were deliberately anonymized — no real
  auditor names, no real investor identities. Keep it that way unless the
  user explicitly says otherwise.

---

## Stay domain-agnostic

The app is reusable across domains — investor data rooms, sales rooms,
internal docs, whatever. Domain-specific concepts (compliance stages,
auditors, frameworks, product names) live **only** in:

- seed data (`db/seeds/customer_attributes.rb` and `db/seeds.rb`),
- `AttributeDefinition` rows the user creates at runtime,
- `Subscription.product_code` values driven by `config/stripe_products.yml`.

Do **not** add to core code:

- model scopes named after a specific industry/customer/product
  (e.g. no `for_compliance`, `for_acme`, etc. — only generic ones like
  `for_product(code)` that take the value as an argument),
- view branches on hardcoded attribute keys or values,
- widget partials that look up `compliance_stage` (or any specific key) by
  literal string. Use widget arguments (`[CUSTOMER_PIPELINE:my_key]`) or
  auto-discover (group by every distinct `product_code`).

When in doubt, ask: "would this still make sense for a use case I haven't
been told about?" If no, parameterize it.

## Push view logic into helpers

Don't put non-trivial Ruby into ERB. ERB blocks aren't unit-testable; you
only catch a syntax error or wrong branch when a controller test happens
to render the full view (and that's how the dashboard's `<% case mode %>`
quietly crashed for a release until the first dashboard test was written).

**Rule of thumb:** if the line contains a `case`, a ternary chain, a
class-string concatenation, or anything that's not a one-liner expression
— put it in a helper that returns the HTML via `tag` / `content_tag` /
`safe_join`, then test the helper in isolation in `test/helpers/`.

Fine in ERB: direct interpolation (`<%= page.title %>`), simple `if`
guards around a chunk of HTML, `link_to`/`button_to` with literal options,
iterating a collection to render the same partial. Anything more goes in
`app/helpers/`.

When the controller has to gather a bunch of related state for the view
(e.g. `configured? + mode + last_sync_at + summary`), build the hash in
the controller and pass one ivar (`@stripe = {...}`) — don't compute it
inside the ERB.

## Page visibility — single concept

`Page#visibility` is a three-value enum (`draft / public / private`) with
`prefix: true` so the methods are `visibility_draft?`, `visibility_public?`,
`visibility_private?`. `Page.live` returns `public + private` (everything that
isn't a draft). `PageAccess` is **only** the allowlist for `private` pages —
no `mode` enum, no `hidden` semantics, presence = "this investor can see this
private page". Don't reintroduce a `published` boolean or a `hidden` mode.
Saving a non-private page wipes its allowlist via `clear_allowlist_if_not_private`.

## What NOT to do

- Don't add a JS framework (React/Vue/etc.) — Hotwire only.
- Don't introduce Redis or Postgres — the whole stack is intentionally one
  SQLite file. If a feature needs another data store, push back first.
- Don't remove the `parallelize(workers: 1)` line in `test_helper.rb` until
  shoulda-context fixes its reporter patch upstream.
- Don't add a `tools/` subdirectory under `app/mcp/` — Zeitwerk would
  require a `Tools::` namespace that the existing classes don't have.
- Don't introduce `password_digest` back on `Investor` — investor auth is
  intentionally a single-field access code (admin-set or auto-generated).
- Don't commit unless explicitly asked.

---

## Useful one-liners

```bash
bin/rails db:seed                              # rebuild defaults; print creds
bin/rails runner 'StripeSyncJob.perform_now'   # manual stripe sync
bin/rails runner 'MonthlySnapshotJob.perform_now(force: true)'
bin/rails routes -g mcp                        # see MCP mount
bin/rails runner 'puts User.first.api_token'   # current admin's MCP token
```
