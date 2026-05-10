module Admin::DashboardsHelper
  def stripe_api_key_badge(configured)
    if configured
      tag.span("Set", class: "badge badge-success badge-sm")
    else
      safe_join([
        tag.span("Missing", class: "badge badge-error badge-sm"),
        tag.span(" add to credentials or ".html_safe + tag.code("STRIPE_API_KEY"),
                 class: "text-xs text-base-content/60 ml-1")
      ])
    end
  end

  CUSTOMER_IMPORT_BADGES = {
    none:   { css: "badge badge-soft",                label: "None" },
    all:    { css: "badge badge-soft badge-info",     label: "All" },
    paying: { css: "badge badge-soft badge-success",  label: "Paying only" }
  }.freeze

  def customer_import_badge(mode)
    cfg = CUSTOMER_IMPORT_BADGES.fetch(mode.to_sym, { css: "badge", label: mode.to_s })
    tag.span(cfg[:label], class: cfg[:css])
  end

  def last_sync_summary_text(summary)
    return nil if summary.blank?
    parts = []
    parts << "#{summary[:customers]} customers"          if summary.key?(:customers)
    parts << "#{summary[:subscriptions]} subscriptions"  if summary.key?(:subscriptions)
    parts << "#{summary[:payments]} payments"            if summary.key?(:payments)
    parts.join(" · ").presence
  end

  def mrr_dollars(cents)
    "$#{number_with_delimiter((cents || 0) / 100)}"
  end

  def page_view_row_time(viewed_at)
    "#{time_ago_in_words(viewed_at)} ago"
  end
end
