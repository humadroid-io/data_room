class GetPageTool < ApplicationTool
  description "Fetch a single page by id or path, including its body HTML."
  input_schema(
    properties: {
      id:   { type: "integer", description: "Page id." },
      path: { type: "string",  description: "Absolute page path, e.g. '/company/team'." }
    }
  )

  def self.call(id: nil, path: nil, server_context:)
    page = Page.find_by(id: id) if id
    page ||= Page.find_by(path: path) if path
    return error("Page not found") unless page

    json(page_summary(page).merge(body_html: page.body.to_s))
  end
end
