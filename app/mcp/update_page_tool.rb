class UpdatePageTool < ApplicationTool
  description "Update a page identified by id or path. Only provided fields are changed."
  input_schema(
    properties: {
      id:          { type: "integer" },
      path:        { type: "string", description: "Use either id or path to identify the page." },
      title:       { type: "string" },
      slug:        { type: "string" },
      parent_path: { type: "string", description: "Move under this parent (use empty string for top-level)." },
      tldr:        { type: "string" },
      body_html:   { type: "string", description: "Replaces the body. To leave unchanged, omit." },
      visibility:  { type: "string", enum: %w[draft public private] },
      sort_order:  { type: "integer" }
    }
  )

  def self.call(id: nil, path: nil, title: nil, slug: nil, parent_path: nil,
                tldr: nil, body_html: nil, visibility: nil, sort_order: nil,
                server_context:)
    page = Page.find_by(id: id) if id
    page ||= Page.find_by(path: path) if path
    return error("Page not found") unless page

    attrs = {}
    attrs[:title]      = title       unless title.nil?
    attrs[:slug]       = slug        unless slug.nil?
    attrs[:tldr]       = tldr        unless tldr.nil?
    attrs[:visibility] = visibility  unless visibility.nil?
    attrs[:sort_order] = sort_order  unless sort_order.nil?

    unless parent_path.nil?
      if parent_path == ""
        attrs[:parent] = nil
      else
        parent = Page.find_by(path: parent_path)
        return error("Parent path '#{parent_path}' not found") unless parent
        attrs[:parent] = parent
      end
    end

    page.assign_attributes(attrs)
    page.body = body_html unless body_html.nil?

    if page.save
      json(page_summary(page).merge(body_html: page.body.to_s))
    else
      error(page.errors.full_messages.join("; "))
    end
  end
end
