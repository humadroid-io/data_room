class CreatePageTool < ApplicationTool
  description <<~DESC
    Create a new page. Slug must be lowercase a-z0-9 with hyphens (or empty for the
    single root landing page). The body accepts plain HTML and the following widget
    tokens: [CHILD_PAGES], [CHILD_PAGES_2_COL], [CUSTOMER_PIPELINE],
    [RETENTION_COHORT], [ACCOUNT_MOVEMENTS], [ACTIVE_ACCOUNTS],
    [MONTHLY_REVENUE], [CHURN_RATE], [MRR_WALK], [NRR_GRR], [QUICK_RATIO].

    Visibility: "draft" (admin only), "public" (every signed-in investor),
    or "private" (only investors listed in allowed_investor_emails).
  DESC

  input_schema(
    properties: {
      title:                   { type: "string" },
      slug:                    { type: "string" },
      parent_path:             { type: "string", description: "Path of the parent page; omit for top-level." },
      tldr:                    { type: "string" },
      body_html:               { type: "string", description: "Inner HTML for the body." },
      visibility:              { type: "string", enum: %w[draft public private] },
      allowed_investor_emails: { type: "array", items: { type: "string" }, description: "Used only when visibility=private." },
      sort_order:              { type: "integer" }
    },
    required: [ "title", "slug" ]
  )

  def self.call(title:, slug:, parent_path: nil, tldr: nil, body_html: nil,
                visibility: "draft", allowed_investor_emails: [], sort_order: 0,
                server_context:)
    parent = parent_path && Page.find_by(path: parent_path)
    return error("Parent path '#{parent_path}' not found") if parent_path && parent.nil?

    page = Page.new(
      title:      title,
      slug:       slug,
      parent:     parent,
      tldr:       tldr,
      visibility: visibility,
      sort_order: sort_order
    )
    page.body = body_html if body_html

    if page.save
      apply_allowlist(page, allowed_investor_emails) if page.visibility_private?
      json(page_summary(page))
    else
      error(page.errors.full_messages.join("; "))
    end
  end

  def self.apply_allowlist(page, emails)
    return if emails.blank?
    Investor.where(email: emails).each do |investor|
      page.page_accesses.find_or_create_by!(investor: investor)
    end
  end
end
