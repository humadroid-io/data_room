# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_10_200001) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attribute_definitions", force: :cascade do |t|
    t.boolean "capture_on_snapshot", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "data_type", null: false
    t.text "description"
    t.string "key", null: false
    t.string "label", null: false
    t.json "options"
    t.boolean "required", default: false, null: false
    t.string "resource_type", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["resource_type", "key"], name: "index_attribute_definitions_on_resource_type_and_key", unique: true
    t.index ["resource_type", "sort_order"], name: "index_attribute_definitions_on_resource_type_and_sort_order"
  end

  create_table "customers", force: :cascade do |t|
    t.string "anonymized_label"
    t.integer "churn_reason_category"
    t.text "churn_reason_notes"
    t.date "churned_on"
    t.datetime "created_at", null: false
    t.json "custom_attributes", default: {}
    t.string "name", null: false
    t.text "notes"
    t.boolean "reference_call_ok", default: false, null: false
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.index ["churn_reason_category"], name: "index_customers_on_churn_reason_category"
    t.index ["churned_on"], name: "index_customers_on_churned_on"
    t.index ["stripe_customer_id"], name: "index_customers_on_stripe_customer_id", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "kind", default: 6, null: false
    t.date "occurred_on", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["occurred_on"], name: "index_events_on_occurred_on"
  end

  create_table "investors", force: :cascade do |t|
    t.string "access_code", null: false
    t.datetime "access_expires_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "fund_name"
    t.datetime "last_login_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "watermark_label", null: false
    t.index ["access_code"], name: "index_investors_on_access_code", unique: true
    t.index ["email"], name: "index_investors_on_email", unique: true
  end

  create_table "page_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "investor_id", null: false
    t.integer "page_id", null: false
    t.datetime "updated_at", null: false
    t.index ["investor_id"], name: "index_page_accesses_on_investor_id"
    t.index ["page_id", "investor_id"], name: "index_page_accesses_on_page_id_and_investor_id", unique: true
    t.index ["page_id"], name: "index_page_accesses_on_page_id"
  end

  create_table "page_redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "old_path", null: false
    t.integer "page_id", null: false
    t.datetime "updated_at", null: false
    t.index ["old_path"], name: "index_page_redirects_on_old_path", unique: true
    t.index ["page_id"], name: "index_page_redirects_on_page_id"
  end

  create_table "page_views", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "investor_id", null: false
    t.string "ip_address"
    t.integer "page_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "viewed_at", null: false
    t.index ["investor_id", "viewed_at"], name: "index_page_views_on_investor_id_and_viewed_at"
    t.index ["investor_id"], name: "index_page_views_on_investor_id"
    t.index ["page_id", "viewed_at"], name: "index_page_views_on_page_id_and_viewed_at"
    t.index ["page_id"], name: "index_page_views_on_page_id"
  end

  create_table "pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "parent_id"
    t.string "path", null: false
    t.string "slug", null: false
    t.integer "sort_order", default: 0, null: false
    t.string "title", null: false
    t.text "tldr"
    t.datetime "updated_at", null: false
    t.integer "visibility", default: 0, null: false
    t.index ["parent_id", "sort_order"], name: "index_pages_on_parent_id_and_sort_order"
    t.index ["parent_id"], name: "index_pages_on_parent_id"
    t.index ["path"], name: "index_pages_on_path", unique: true
    t.index ["visibility"], name: "index_pages_on_visibility"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "usd", null: false
    t.integer "customer_id", null: false
    t.datetime "paid_at", null: false
    t.string "stripe_charge_id"
    t.string "stripe_invoice_id", null: false
    t.integer "subscription_id"
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_payments_on_customer_id"
    t.index ["paid_at"], name: "index_payments_on_paid_at"
    t.index ["stripe_invoice_id"], name: "index_payments_on_stripe_invoice_id", unique: true
    t.index ["subscription_id"], name: "index_payments_on_subscription_id"
  end

  create_table "snapshots", force: :cascade do |t|
    t.json "captured_attributes", default: {}
    t.datetime "created_at", null: false
    t.integer "mrr_cents", null: false
    t.date "snapshot_date", null: false
    t.integer "status", null: false
    t.integer "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["snapshot_date"], name: "index_snapshots_on_snapshot_date"
    t.index ["subscription_id", "snapshot_date"], name: "index_snapshots_on_subscription_id_and_snapshot_date", unique: true
    t.index ["subscription_id"], name: "index_snapshots_on_subscription_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "usd", null: false
    t.json "custom_attributes", default: {}
    t.integer "customer_id", null: false
    t.datetime "last_synced_at"
    t.integer "mrr_cents", default: 0, null: false
    t.datetime "paused_at"
    t.string "product_code"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.string "stripe_customer_id", null: false
    t.string "stripe_price_id"
    t.string "stripe_subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_subscriptions_on_customer_id"
    t.index ["status", "product_code"], name: "index_subscriptions_on_status_and_product_code"
    t.index ["stripe_customer_id"], name: "index_subscriptions_on_stripe_customer_id"
    t.index ["stripe_price_id"], name: "index_subscriptions_on_stripe_price_id"
    t.index ["stripe_subscription_id"], name: "index_subscriptions_on_stripe_subscription_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "api_token"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["api_token"], name: "index_users_on_api_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "page_accesses", "investors"
  add_foreign_key "page_accesses", "pages"
  add_foreign_key "page_redirects", "pages"
  add_foreign_key "page_views", "investors"
  add_foreign_key "page_views", "pages"
  add_foreign_key "pages", "pages", column: "parent_id"
  add_foreign_key "payments", "customers"
  add_foreign_key "payments", "subscriptions"
  add_foreign_key "snapshots", "subscriptions"
  add_foreign_key "subscriptions", "customers"
end
