# Humadroid Data Room - MVP Spec

> **Status:** v2 (consolidated). Supersedes v1.
> **Target:** 2-3 iterations, ~3 weeks of focused work
> **Stack:** Rails 8.x, SQLite, Solid Queue/Cache/Cable, Lexxy (ActionText), Hotwire, Tailwind

---

## Goal

A self-hosted data room that:

1. Renders investor-facing pages, hierarchically organized, password-gated, watermarked
2. Pulls customer + subscription data from Stripe and renders MRR / cohort / retention dashboards
3. Lets admins (Maciej, Luk) define custom attributes per resource and edit content from an admin UI
4. Supports per-page-per-investor visibility so a sensitive page can be hidden from a specific VC
5. Tracks who viewed what, when

**Design principle:** the app is generic enough to be reused for non-compliance use cases. Compliance-specific data lives as custom attributes and seed data, not in core schema.

Out of scope for v1: collaborative editing, NDA flows, expiring per-page links, custom domains per investor, e-signing, multi-tenant SaaS.

---

## Stack decisions

- **Rails 8 + SQLite.** No Postgres. No Redis. Solid Queue for jobs, Solid Cache, Solid Cable. Backups via Litestream to S3 / R2 / B2.
- **Action Cable** scope: broadcast on Stripe sync completion so dashboards refresh without reload. That's the only WebSocket use.
- **Lexxy (ActionText)** for rich text on Page bodies. `has_rich_text :body`. Custom widgets via placeholder tokens ([CHILD_PAGES] etc.) parsed server-side at render. Upgrade path to ActionText attachables when placeholders gripe.
- **Hotwire (Turbo + Stimulus)** for everything else. No SPA framework.
- **Tailwind** via the official Rails integration.
- **Charts:** Chartkick + Chart.js.
- **Auth:** plain bcrypt via `has_secure_password`. Two models: `User` (admin) and `Investor` (read-only access). Separate sessions, separate cookies.
- **Stripe sync:** cron-driven daily pull, not webhook. Idempotent.
- **Deploy:** Kamal 2 to a $20-40/mo VPS. One container, one DB volume, Litestream sidecar.

---

## Data model

### Tables

```
users                    # admins (Maciej, Luk)
investors                # read-only data room access
pages                    # hierarchical, with rich text body, paths, visibility
page_accesses            # per-page-per-investor visibility overrides
page_redirects           # old paths -> page_id, populated on slug/parent change
page_views               # analytics
attribute_definitions    # schema for custom fields, polymorphic by resource type
customers                # generic customer record + custom_attributes JSON
subscriptions            # Stripe-mirrored, 1 customer can have N
snapshots                # append-only time-series of subscription state
documents                # Active Storage attachments on Pages
```

---

### User + Investor (auth)

```ruby
create_table :users do |t|
  t.string  :name, null: false
  t.string  :email, null: false
  t.string  :password_digest, null: false
  t.integer :role, default: 0                            # enum: admin, viewer
  t.timestamps

  t.index :email, unique: true
end

create_table :investors do |t|
  t.string  :name, null: false                           # "Aleksandra @ Vastpoint"
  t.string  :fund_name
  t.string  :email
  t.string  :password_digest, null: false
  t.string  :watermark_label, null: false                # shown on every page
  t.datetime :access_expires_at
  t.datetime :last_login_at
  t.boolean :active, default: true
  t.timestamps

  t.index :email, unique: true
end

class User < ApplicationRecord
  has_secure_password
  enum :role, %i[admin viewer], default: :admin
end

class Investor < ApplicationRecord
  has_secure_password
  has_many :page_views, dependent: :destroy
  has_many :page_accesses, dependent: :destroy

  scope :usable, -> {
    where(active: true).where(
      "access_expires_at IS NULL OR access_expires_at > ?", Time.current
    )
  }
end
```

Two separate models, two separate session controllers, two separate cookies (different cookie names). Admin signs in to `/admin/login`, investor to `/login`. No mixing.

---

### Page (hierarchical, with paths)

```ruby
create_table :pages do |t|
  t.references :parent, foreign_key: { to_table: :pages }, index: true
  t.string  :slug, null: false                           # URL segment, empty for root
  t.string  :path, null: false                           # cached, e.g. "/pipeline/moms-growth"
  t.string  :title, null: false
  t.integer :sort_order, default: 0
  t.boolean :published, default: false
  t.text    :tldr                                        # short summary, rendered as callout
  t.timestamps

  t.index :path, unique: true
  t.index [:parent_id, :sort_order]
end

class Page < ApplicationRecord
  belongs_to :parent, class_name: 'Page', optional: true
  has_many :children, -> { order(:sort_order) },
           class_name: 'Page', foreign_key: :parent_id, dependent: :destroy
  has_rich_text :body
  has_many_attached :documents
  has_many :page_views, dependent: :destroy
  has_many :page_accesses, dependent: :destroy
  has_many :page_redirects, dependent: :destroy

  validates :slug, format: /\A[a-z0-9-]*\z/               # empty allowed for root
  validates :path, presence: true, uniqueness: true,
            format: /\A\/[a-z0-9\-\/]*\z/

  before_validation :compute_path
  before_save       :create_redirect_if_path_changed
  after_save        :recompute_descendant_paths, if: :saved_change_to_path?

  scope :landing,   -> { find_by(path: '/') }
  scope :published, -> { where(published: true) }

  def root_landing? = parent_id.nil? && slug.blank?

  def visible_to?(investor)
    return false unless published
    !page_accesses.where(investor: investor, mode: :hidden).exists?
  end

  def visible_children_for(investor)
    children.published.select { |c| c.visible_to?(investor) }
  end

  private

  def compute_path
    self.path = if root_landing?
      '/'
    elsif parent.nil?
      "/#{slug}"
    else
      [parent.path, slug].join('/').gsub('//', '/')
    end
  end

  def create_redirect_if_path_changed
    if persisted? && path_changed? && path_was.present?
      page_redirects.build(old_path: path_was)
    end
  end

  def recompute_descendant_paths
    children.each(&:save!)
  end
end
```

**Constraint "only one root page":** unique index on `path` enforces it. Whichever page has `slug = ""` and `parent_id = nil` is the landing page. There can only be one with `path = "/"`.

**Routing:**

```ruby
# routes.rb
Rails.application.routes.draw do
  root to: 'pages#show'

  namespace :admin do
    resources :sessions, only: %i[new create destroy]
    resources :pages
    resources :customers
    resources :subscriptions
    resources :investors
    resources :attribute_definitions
  end

  resource :session, only: %i[new create destroy]

  # catch-all for hierarchical pages, must be last
  get '*path', to: 'pages#show', constraints: { path: /[a-z0-9\-\/]*/ }
end
```

```ruby
class PagesController < ApplicationController
  before_action :require_investor

  def show
    requested = "/#{params[:path]}".gsub(/\/+/, '/').sub(/\/$/, '').presence || '/'

    @page = Page.published.find_by(path: requested) ||
            follow_redirect(requested) ||
            (raise ActiveRecord::RecordNotFound)

    raise ActionController::RoutingError, 'Forbidden' unless @page.visible_to?(current_investor)

    PageView.create!(investor: current_investor, page: @page, viewed_at: Time.current)
    render :show
  end

  private

  def follow_redirect(old_path)
    redirect = PageRedirect.find_by(old_path: old_path)
    redirect&.page
  end
end
```

---

### PageAccess (per-investor visibility)

```ruby
create_table :page_accesses do |t|
  t.references :page, null: false, foreign_key: true
  t.references :investor, null: false, foreign_key: true
  t.integer    :mode, default: 0                         # enum: hidden, granted
  t.timestamps

  t.index [:page_id, :investor_id], unique: true
end

class PageAccess < ApplicationRecord
  belongs_to :page
  belongs_to :investor
  enum :mode, %i[hidden granted]
end
```

V1 semantics:
- Default: published page is visible to all logged-in investors
- `PageAccess(mode: :hidden)` makes the page invisible to that investor

V2 semantics (no migration needed, just a new column on Page):
- Add `Page.access_mode` enum (`default_open`, `default_closed`)
- For `default_closed` pages, `granted` records are required for visibility

Admin UI in v1: each Page has a "hide from" multi-select of investors. Saves `hidden` records. Three lines in the form.

---

### PageRedirect (old paths)

```ruby
create_table :page_redirects do |t|
  t.references :page, null: false, foreign_key: true
  t.string     :old_path, null: false
  t.timestamps

  t.index :old_path, unique: true
end

class PageRedirect < ApplicationRecord
  belongs_to :page
end
```

Created automatically in `Page#create_redirect_if_path_changed`. If an investor has an old URL bookmarked, they get to the new page transparently.

---

### AttributeDefinition (custom fields schema)

```ruby
create_table :attribute_definitions do |t|
  t.string  :resource_type, null: false                  # e.g., "Customer", "Subscription"
  t.string  :key, null: false                            # snake_case, e.g., "compliance_stage"
  t.string  :label, null: false                          # display name
  t.text    :description
  t.integer :data_type, null: false                      # enum
  t.json    :options                                     # for select types: [{value, label, color}]
  t.boolean :required, default: false
  t.boolean :capture_on_snapshot, default: false         # only meaningful for Customer
  t.integer :sort_order, default: 0
  t.timestamps

  t.index [:resource_type, :key], unique: true
  t.index [:resource_type, :sort_order]
end

class AttributeDefinition < ApplicationRecord
  enum :data_type, %i[
    string text integer decimal date boolean
    single_select multi_select
  ]

  validates :key, format: /\A[a-z][a-z0-9_]*\z/
  validates :resource_type, presence: true

  scope :for_resource, ->(klass) { where(resource_type: klass.to_s).order(:sort_order) }
  scope :captured,     -> { where(capture_on_snapshot: true) }
end
```

**Why a definition table.** The alternative is "just put a JSON column on Customer and edit it freely." That works for one developer who never forgets schema. It does not work for an admin UI that needs to render forms, validate input, or display values with proper labels. Definitions table gives us all of that for the cost of one extra model.

**`options` shape for select types:**

```json
[
  {"value": "onboarding", "label": "Onboarding", "color": "gray"},
  {"value": "implementation", "label": "Implementation", "color": "blue"},
  {"value": "audit_ready", "label": "Audit-ready", "color": "orange"},
  {"value": "in_audit", "label": "In audit", "color": "yellow"},
  {"value": "certified", "label": "Certified", "color": "green"},
  {"value": "on_hold", "label": "On hold", "color": "red"}
]
```

**`capture_on_snapshot`:** marks attributes that should be captured per-month into Snapshot for historical analysis. For Humadroid, `compliance_stage` is captured (so retention curves can show stage progression), `notes` is not.

---

### HasCustomAttributes (concern)

```ruby
# app/models/concerns/has_custom_attributes.rb
module HasCustomAttributes
  extend ActiveSupport::Concern

  included do
    validate :validate_custom_attributes
  end

  def custom_attribute(key)
    custom_attributes[key.to_s]
  end

  def set_custom_attribute(key, value)
    self.custom_attributes = (custom_attributes || {}).merge(key.to_s => value)
  end

  def attribute_definitions
    AttributeDefinition.for_resource(self.class)
  end

  def custom_attribute_label(key)
    defn = attribute_definitions.find { |d| d.key == key }
    return nil unless defn

    value = custom_attribute(key)
    return value if value.blank?
    return value unless %w[single_select multi_select].include?(defn.data_type)

    options_map = (defn.options || []).index_by { |o| o['value'] }
    if defn.single_select?
      options_map[value]&.dig('label') || value
    else
      Array(value).map { |v| options_map[v]&.dig('label') || v }
    end
  end

  def captured_attributes_for_snapshot
    keys = attribute_definitions.captured.pluck(:key)
    (custom_attributes || {}).slice(*keys)
  end

  private

  def validate_custom_attributes
    attribute_definitions.each do |defn|
      value = custom_attribute(defn.key)

      if defn.required && value.blank?
        errors.add(:custom_attributes, "#{defn.label} is required")
        next
      end

      next if value.blank?

      case defn.data_type
      when 'integer'
        errors.add(:custom_attributes, "#{defn.label} must be an integer") unless value.to_s.match?(/\A-?\d+\z/)
      when 'date'
        Date.parse(value.to_s) rescue errors.add(:custom_attributes, "#{defn.label} is not a valid date")
      when 'single_select'
        valid = (defn.options || []).map { |o| o['value'] }
        errors.add(:custom_attributes, "#{defn.label} has invalid value") unless valid.include?(value)
      when 'multi_select'
        unless value.is_a?(Array)
          errors.add(:custom_attributes, "#{defn.label} must be an array")
        else
          valid = (defn.options || []).map { |o| o['value'] }
          errors.add(:custom_attributes, "#{defn.label} has invalid values") if (value - valid).any?
        end
      end
    end
  end
end
```

**Querying custom attributes (SQLite JSON1):**

```ruby
class Customer < ApplicationRecord
  scope :with_custom_attribute, ->(key, value) {
    where("json_extract(custom_attributes, '$.#{ActiveRecord::Base.sanitize_sql_for_conditions(key)}') = ?", value)
  }

  scope :with_custom_attribute_containing, ->(key, value) {
    where("EXISTS (SELECT 1 FROM json_each(json_extract(custom_attributes, '$.#{key}')) WHERE value = ?)", value)
  }
end

# Usage
Customer.with_custom_attribute('compliance_stage', 'implementation')
Customer.with_custom_attribute('compliance_stage', 'in_audit').count
Customer.with_custom_attribute_containing('frameworks', 'soc2')
```

Performance is fine for the data room scale. If a query gets hot, add a generated column + index in SQLite.

---

### Customer (generic)

```ruby
create_table :customers do |t|
  t.string  :name, null: false                           # company name (admin only)
  t.string  :anonymized_label                            # "AI SaaS, 12 employees" (investor view)
  t.text    :notes
  t.boolean :reference_call_ok, default: false
  t.json    :custom_attributes, default: {}
  t.timestamps
end

class Customer < ApplicationRecord
  include HasCustomAttributes

  has_many :subscriptions, dependent: :destroy

  scope :reference_capable, -> { where(reference_call_ok: true) }
end
```

That's it. Customer has zero compliance-specific fields. Everything Humadroid-specific lives in `custom_attributes` and is defined in `attribute_definitions`.

**Seed data for Humadroid:**

```ruby
# db/seeds/humadroid_attributes.rb

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'compliance_stage'
) do |a|
  a.label = 'Compliance stage'
  a.data_type = :single_select
  a.options = [
    {value: 'onboarding',     label: 'Onboarding',     color: 'gray'},
    {value: 'implementation', label: 'Implementation', color: 'blue'},
    {value: 'audit_ready',    label: 'Audit-ready',    color: 'orange'},
    {value: 'in_audit',       label: 'In audit',       color: 'yellow'},
    {value: 'certified',      label: 'Certified',      color: 'green'},
    {value: 'on_hold',        label: 'On hold',        color: 'red'}
  ]
  a.required = true
  a.capture_on_snapshot = true
  a.sort_order = 1
end

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'frameworks'
) do |a|
  a.label = 'Frameworks'
  a.data_type = :multi_select
  a.options = [
    {value: 'soc2',      label: 'SOC 2',      color: 'blue'},
    {value: 'iso27001',  label: 'ISO 27001',  color: 'purple'},
    {value: 'hipaa',     label: 'HIPAA',      color: 'green'}
  ]
  a.capture_on_snapshot = false
  a.sort_order = 2
end

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'auditor'
) do |a|
  a.label = 'Auditor'
  a.data_type = :single_select
  a.options = [
    {value: 'constellation_grc', label: 'ConstellationGRC', color: 'green'},
    {value: 'external',          label: 'External',         color: 'gray'},
    {value: 'tbd',               label: 'TBD',              color: 'gray'}
  ]
  a.sort_order = 3
end

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'audit_scheduled'
) do |a|
  a.label = 'Audit scheduled'
  a.data_type = :date
  a.sort_order = 4
end

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'cert_delivered'
) do |a|
  a.label = 'Cert delivered'
  a.data_type = :date
  a.sort_order = 5
end

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'industry'
) do |a|
  a.label = 'Industry'
  a.data_type = :single_select
  a.options = [
    {value: 'heavy_saas',          label: 'Heavy SaaS',          color: 'blue'},
    {value: 'critical_path_tools', label: 'Critical-path tools', color: 'orange'},
    {value: 'ai_saas',             label: 'AI SaaS',             color: 'purple'},
    {value: 'other',               label: 'Other',               color: 'gray'}
  ]
  a.sort_order = 6
end

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'acquired_via'
) do |a|
  a.label = 'Acquired via'
  a.data_type = :single_select
  a.options = [
    {value: 'reddit',          label: 'Reddit',           color: 'red'},
    {value: 'linkedin',        label: 'LinkedIn',         color: 'blue'},
    {value: 'network',         label: 'Network',          color: 'green'},
    {value: 'gathr_community', label: 'GATHR/community',  color: 'purple'},
    {value: 'email_outbound',  label: 'Email outbound',   color: 'gray'},
    {value: 'other',           label: 'Other',            color: 'gray'}
  ]
  a.sort_order = 7
end

AttributeDefinition.find_or_create_by!(
  resource_type: 'Customer', key: 'team_size'
) do |a|
  a.label = 'Team size'
  a.data_type = :integer
  a.sort_order = 8
end
```

Forker drops this seed file, writes their own. Customer model doesn't change.

---

### Subscription

```ruby
create_table :subscriptions do |t|
  t.references :customer, null: false, foreign_key: true
  t.string     :stripe_customer_id, null: false
  t.string     :stripe_subscription_id, null: false
  t.string     :product_code, null: false                # "compliance", "compliance_discounted", "legacy_hrms"
  t.integer    :mrr_cents, null: false, default: 0
  t.string     :currency, default: "usd"
  t.integer    :status, default: 0
  t.datetime   :started_at
  t.datetime   :canceled_at
  t.datetime   :paused_at
  t.datetime   :last_synced_at
  t.json       :custom_attributes, default: {}
  t.timestamps

  t.index :stripe_subscription_id, unique: true
  t.index :stripe_customer_id
  t.index [:status, :product_code]
end

class Subscription < ApplicationRecord
  include HasCustomAttributes

  belongs_to :customer
  has_many :snapshots, dependent: :destroy

  enum :status, %i[active past_due canceled paused trialing incomplete], default: :active

  scope :active_now,         -> { where(status: %i[active trialing]) }
  scope :for_product,        ->(code) { where(product_code: code) }
  scope :for_compliance,     -> { where(product_code: %w[compliance compliance_discounted]) }
end
```

**Why `product_code` is a string not an enum.** Different deploys will have different products. Mapping Stripe Price IDs to product codes happens in StripeSyncJob via a config file:

```yaml
# config/stripe_products.yml
production:
  price_1AbCdE...: compliance
  price_1FgHiJ...: compliance_discounted
  price_1KlMnO...: legacy_hrms
```

Sync job reads this, sets product_code accordingly. Adding a new product means adding a line to the config, not migrating the DB.

Customer:Subscription is 1:N. A customer can have legacy HRMS plus compliance, can churn-and-return on a different plan, etc. Subscriptions are append-only-ish: they're never deleted, just their status changes.

---

### Snapshot

```ruby
create_table :snapshots do |t|
  t.references :subscription, null: false, foreign_key: true
  t.date       :snapshot_date, null: false               # always first-of-month
  t.integer    :mrr_cents, null: false
  t.integer    :status, null: false
  t.json       :captured_attributes, default: {}         # filtered Customer.custom_attributes at that time
  t.timestamps

  t.index [:subscription_id, :snapshot_date], unique: true
  t.index :snapshot_date
end

class Snapshot < ApplicationRecord
  belongs_to :subscription
  enum :status, %i[active past_due canceled paused trialing incomplete]

  delegate :customer, to: :subscription

  def captured_attribute(key)
    captured_attributes[key.to_s]
  end
end
```

`captured_attributes` stores the Customer's custom_attributes that have `capture_on_snapshot: true`, at the time of the snapshot. For Humadroid, that's `compliance_stage`. If `capture_on_snapshot` is later flipped on for `auditor`, future snapshots include it; older ones don't (don't backfill, just notice the gap).

**Aggregate queries:**

```ruby
# MoM compliance MRR
Snapshot.joins(:subscription)
  .merge(Subscription.for_compliance)
  .group(:snapshot_date)
  .sum(:mrr_cents)

# Active customers in compliance per month
Snapshot.joins(:subscription)
  .merge(Subscription.for_compliance)
  .where(status: %i[active trialing])
  .group(:snapshot_date)
  .distinct
  .count('subscriptions.customer_id')

# Customers in 'in_audit' stage by month
Snapshot.where("json_extract(captured_attributes, '$.compliance_stage') = ?", 'in_audit')
  .group(:snapshot_date)
  .distinct
  .count('subscriptions.customer_id')
```

---

### PageView

```ruby
create_table :page_views do |t|
  t.references :investor, null: false, foreign_key: true
  t.references :page, null: false, foreign_key: true
  t.datetime   :viewed_at, null: false
  t.string     :ip_address
  t.timestamps

  t.index [:investor_id, :viewed_at]
  t.index [:page_id, :viewed_at]
end
```

Append on every page hit. Aggregate in admin dashboard.

---

## Stripe sync

```ruby
# config/recurring.yml
production:
  stripe_sync:
    class: StripeSyncJob
    schedule: every day at 3am UTC
  monthly_snapshot:
    class: MonthlySnapshotJob
    schedule: every day at 4am UTC      # job no-ops on day 2-31
```

```ruby
class StripeSyncJob < ApplicationJob
  def perform
    Stripe::Subscription.list(
      status: 'all', limit: 100,
      expand: ['data.items.data.price']
    ).auto_paging_each do |stripe_sub|
      sync_subscription(stripe_sub)
    end

    ActionCable.server.broadcast('data_room', { event: 'stripe_synced', at: Time.current.iso8601 })
  end

  private

  def sync_subscription(s)
    sub = Subscription.find_or_initialize_by(stripe_subscription_id: s.id)

    sub.assign_attributes(
      stripe_customer_id: s.customer,
      mrr_cents:    extract_mrr_cents(s),
      currency:     s.currency,
      status:       map_status(s.status),
      product_code: resolve_product_code(s),
      started_at:   Time.at(s.start_date),
      canceled_at:  s.canceled_at ? Time.at(s.canceled_at) : nil,
      paused_at:    s.pause_collection ? Time.current : nil,
      last_synced_at: Time.current
    )

    sub.customer ||= Customer.joins(:subscriptions)
                              .where(subscriptions: { stripe_customer_id: s.customer })
                              .first
    return Rails.logger.warn("Orphan subscription: #{s.id}") unless sub.customer

    sub.save!
  end

  def extract_mrr_cents(s)
    s.items.data.sum do |item|
      price = item.price
      case price.recurring.interval
      when 'month' then price.unit_amount * item.quantity
      when 'year'  then (price.unit_amount * item.quantity) / 12
      else 0
      end
    end
  end

  def map_status(stripe_status)
    {
      'active'             => :active,
      'past_due'           => :past_due,
      'canceled'           => :canceled,
      'unpaid'             => :past_due,
      'paused'             => :paused,
      'trialing'           => :trialing,
      'incomplete'         => :incomplete,
      'incomplete_expired' => :canceled
    }.fetch(stripe_status, :incomplete)
  end

  def resolve_product_code(s)
    price_id = s.items.data.first&.price&.id
    Rails.application.config.stripe_products[price_id] || 'unknown'
  end
end

class MonthlySnapshotJob < ApplicationJob
  def perform
    return unless Date.current.day == 1

    Subscription.find_each do |sub|
      next unless sub.customer

      Snapshot.create!(
        subscription: sub,
        snapshot_date: Date.current,
        mrr_cents: sub.mrr_cents,
        status: sub.status,
        captured_attributes: sub.customer.captured_attributes_for_snapshot
      )
    end
  end
end
```

**Why daily not webhook.** "MRR up by $250 since lunch" is not a useful real-time signal at this stage. Daily is fine and removes signature verification, idempotency handling, and retry logic from your surface.

**Customers are not auto-created from Stripe.** Maciej creates Customer in admin UI first, sets `stripe_customer_id` (free text or a search-and-pick from Stripe API). Sync only upserts Subscriptions. Orphan subscriptions are logged.

**Backfill:** before going live, write a one-off rake task that walks Stripe invoices for past months and constructs historical Snapshot rows so the cohort charts have something on day one. Half-day task.

---

## Page rendering + custom widgets

Widgets via placeholder tokens parsed at render time.

```ruby
# app/helpers/pages_helper.rb
module PagesHelper
  WIDGET_RE = /\[(CHILD_PAGES|CHILD_PAGES_2_COL|CUSTOMER_PIPELINE|MOMS_GROWTH_CHART|RETENTION_COHORT)\]/

  def render_page_body(page, investor)
    html = page.body.to_s
    html.gsub(WIDGET_RE) do
      case Regexp.last_match[1]
      when 'CHILD_PAGES'         then render_children_list(page, investor, cols: 1)
      when 'CHILD_PAGES_2_COL'   then render_children_list(page, investor, cols: 2)
      when 'CUSTOMER_PIPELINE'   then render(partial: 'pages/widgets/customer_pipeline')
      when 'MOMS_GROWTH_CHART'   then render(partial: 'pages/widgets/moms_growth_chart')
      when 'RETENTION_COHORT'    then render(partial: 'pages/widgets/retention_cohort')
      end
    end.html_safe
  end

  def render_children_list(page, investor, cols:)
    children = page.visible_children_for(investor)
    render(partial: 'pages/widgets/children_list',
           locals: { children: children, cols: cols })
  end
end
```

```erb
<%# app/views/pages/widgets/_children_list.html.erb %>
<div class="grid <%= cols == 2 ? 'grid-cols-2 gap-4' : 'grid-cols-1 gap-2' %> my-6">
  <% children.each do |child| %>
    <%= link_to child.path, class: 'block p-4 border rounded hover:bg-gray-50 transition' do %>
      <h3 class="font-semibold"><%= child.title %></h3>
      <% if child.tldr.present? %>
        <p class="text-sm text-gray-600 mt-1"><%= truncate(child.tldr, length: 120) %></p>
      <% end %>
    <% end %>
  <% end %>
</div>
```

```erb
<%# app/views/pages/show.html.erb %>
<article class="prose max-w-none">
  <h1><%= @page.title %></h1>
  <% if @page.tldr.present? %>
    <div class="callout-tldr"><strong>TL;DR</strong> <%= @page.tldr %></div>
  <% end %>
  <%= render_page_body(@page, current_investor) %>
</article>
```

**Widget visibility cascades for free.** `[CHILD_PAGES]` renders only children that `visible_to?(current_investor)` returns true for. Hidden pages don't appear in widget lists.

**Upgrade path** when placeholders gripe: ActionText custom attachables. Ship as a Stimulus controller + Lexxy extension. Schema doesn't change. ~1 day of work.

---

## Watermark

```erb
<%# app/views/layouts/investor.html.erb %>
<body>
  <%= yield %>
  <div class="fixed inset-0 pointer-events-none flex items-center justify-center -rotate-12 opacity-5 text-6xl font-bold select-none">
    <%= current_investor.watermark_label %>
  </div>
</body>
```

Done.

---

## Action Cable

One channel:

```ruby
class DataRoomChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'data_room'
  end
end
```

Stripe sync broadcasts on completion. Frontend Stimulus controller listens, updates a "last refreshed" timestamp on dashboards. That's it.

---

## Iteration plan

### Iteration 1 - Skeleton (7 days)

- Rails 8 app, SQLite, Tailwind, Lexxy, Hotwire
- Models: User, Investor, Page, PageAccess, PageRedirect, AttributeDefinition, Customer, Subscription, Snapshot, PageView
- HasCustomAttributes concern
- Migrations + seeds (Humadroid attribute definitions, 1 admin user, 1 test investor, root + 4 section pages)
- Admin UI: CRUD for Pages (Lexxy editor, parent picker, hide-from-investors checklist), Customers (with dynamic custom_attributes form rendered from AttributeDefinitions), Subscriptions (manual entry), AttributeDefinitions
- Investor auth + page rendering with hierarchical paths + redirects + visibility
- Watermark, page view tracking
- `[CHILD_PAGES]` and `[CHILD_PAGES_2_COL]` widgets

**Done when:** Maciej can log in as admin, build the page tree (root + sections + subpages), edit content with Lexxy, define custom attributes, populate customers manually. Investor can log in, navigate the tree, see hidden pages disappear from `[CHILD_PAGES]` widgets.

### Iteration 2 - Stripe + dashboards (7 days)

- Stripe gem, API keys in Rails credentials, `config/stripe_products.yml`
- StripeSyncJob (daily via Solid Queue recurring)
- MonthlySnapshotJob (no-op except day 1)
- Backfill rake task for historical snapshots from invoice data
- Three dashboard widgets:
  - `[MOMS_GROWTH_CHART]` (line chart, two series: compliance / legacy)
  - `[CUSTOMER_PIPELINE]` (table, group by compliance_stage from custom_attributes)
  - `[RETENTION_COHORT]` (cohort heatmap or stacked area)
- Action Cable broadcast on sync, Stimulus controller updating "last refreshed" stamp

**Done when:** real Stripe data appears in three widgets embedded in pages. Daily sync runs reliably.

### Iteration 3 - Polish + ship (5 days)

- Active Storage for documents (deck PDF), gated download
- Investor admin UI: create / set expiration / deactivate
- Email when investor logs in (ActionMailer + Postmark / Resend)
- Admin dashboard: who's viewed what, when (PageView aggregations)
- Kamal config + Litestream for SQLite backup to S3 / R2 / B2
- DNS, TLS via Let's Encrypt
- Deploy to Hetzner / DigitalOcean

**Done when:** the live URL is shareable, password-protected, watermarked, pulling real Stripe data, with views logged.

---

## Open questions

Items that need a decision before starting Iteration 1:

1. **Currency normalization.** USD-only for v1, or store native + add USD at snapshot time? My default: USD-only, FX problem when it appears.

2. **Discount handling.** Track list-price MRR alongside actual? My default: actual only; list-price computed from `product_code` if needed for analysis.

3. **Failed payments / retries.** Count `past_due` in MRR? My default: count `active + trialing`, flag `past_due` separately as risk on dashboards.

4. **Anonymization in customer pipeline view.** Investors see `anonymized_label` only or `name` too? My default: anonymized only for investors, names visible to admin.

5. **Backup target.** S3, R2, or B2 for Litestream? My default: R2 (cheap, no egress fees).

6. **Multi-admin roles.** User has `role` enum from day one? My default: yes (`admin`, `viewer`), one row to add a third user.

7. **Root page semantics.** Always content (hero + section links), or auto-redirect to first section? My default: content. The landing matters.

---

## Out of scope (explicit nope list)

To stay inside 2-3 iterations:

- Custom subdomain per investor
- E-signed NDAs as precondition
- Per-page expiration or one-time-view links
- Markdown vs Lexxy choice (Lexxy via ActionText, default toolbar)
- Custom analytics dashboard (PageView aggregations + a few SQL queries)
- Multi-tenant SaaS
- Granular permissions per page beyond hidden/granted
- Internationalization
- Mobile app (responsive Tailwind only)
- ActionText custom attachables (placeholders are enough for v1)
- AttributeDefinition `granted` semantics (allowlist mode for pages)
- Snapshot backfill on `capture_on_snapshot` flip (just notice the gap)

---

## Honest scope risk

The 2-3 iteration estimate assumes:

- You're comfortable with Rails 8 (you are)
- You're not bikeshedding on visual design (do not)
- Stripe API quirks don't bite hard (they will, budget half a day)
- Litestream works first try on Hetzner (might not, budget a day)
- Solid Queue recurring tasks are stable on your Rails 8 minor version
- Custom attributes form rendering doesn't suck Stimulus time (could; budget half-day for the dynamic form)

Realistic outcome: 3-4 weeks of focused work. Faster if you skip Iteration 3 polish (manual deploys, no email notifications, no admin viewing dashboard). The data model itself is solid and shouldn't need a v2 migration round.

---

## Document control

| Version | Date     | Changes                                                                                                                                                                                                |
|---------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| v1      | May 2026 | Initial spec. Customer + ComplianceProfile + Subscription + Snapshot. Flat Page model with section enum.                                                                                              |
| v2      | May 2026 | Page hierarchy with paths and redirects. PageAccess for per-investor visibility. Widget placeholders. Generic Customer with AttributeDefinition + custom_attributes JSON. ComplianceProfile dropped.   |
