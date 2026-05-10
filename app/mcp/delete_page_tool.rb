class DeletePageTool < ApplicationTool
  description "Delete a page (and all its descendants) by id or path."
  input_schema(
    properties: {
      id:   { type: "integer" },
      path: { type: "string" }
    }
  )

  def self.call(id: nil, path: nil, server_context:)
    page = Page.find_by(id: id) if id
    page ||= Page.find_by(path: path) if path
    return error("Page not found") unless page

    page.destroy
    text("Deleted page '#{page.path}' and #{page.children.count} descendants.")
  end
end
