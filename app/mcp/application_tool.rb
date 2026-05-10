class ApplicationTool < MCP::Tool
  class << self
    def text(value)
      MCP::Tool::Response.new([ { type: "text", text: value.to_s } ])
    end

    def json(payload)
      MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(payload) } ])
    end

    def error(message)
      MCP::Tool::Response.new([ { type: "text", text: "Error: #{message}" } ], error: true)
    end

    def page_summary(page)
      {
        id:                  page.id,
        path:                page.path,
        title:               page.title,
        slug:                page.slug,
        parent_id:           page.parent_id,
        visibility:          page.visibility,
        sort_order:          page.sort_order,
        tldr:                page.tldr,
        allowed_investor_ids: page.visibility_private? ? page.allowed_investors.pluck(:id) : nil,
        updated_at:          page.updated_at.iso8601
      }.compact
    end
  end
end
