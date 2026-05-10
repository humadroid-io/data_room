class ListPagesTool < ApplicationTool
  description "List all pages in the data room (path, title, visibility, parent)."
  input_schema(
    properties: {
      live_only: {
        type: "boolean",
        description: "If true, exclude drafts. Returns both public and private pages."
      }
    }
  )

  def self.call(live_only: false, server_context:)
    scope = live_only ? Page.live : Page.all
    pages = scope.includes(:parent).order(:path).map { |p| page_summary(p) }
    json(pages: pages)
  end
end
