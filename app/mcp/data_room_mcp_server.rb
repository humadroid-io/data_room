module DataRoomMcpServer
  module_function

  TOOLS = [
    ListPagesTool, GetPageTool, CreatePageTool, UpdatePageTool, DeletePageTool,
    SetPageVisibilityTool,
    ListInvestorsTool, ListCustomersTool
  ].freeze

  INSTRUCTIONS = <<~TEXT
    Tools for managing the Data Room content. Use list_pages to discover
    the structure, get_page to read content, and create_page / update_page
    to author. Widget tokens (e.g. [CHILD_PAGES], [ACCOUNT_MOVEMENTS]) inside
    body_html are rendered server-side at view time.
  TEXT

  def app
    server = MCP::Server.new(
      name:         "data_room",
      version:      "1.0.0",
      instructions: INSTRUCTIONS,
      tools:        TOOLS
    )
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true)
    TokenAuthMiddleware.new(transport)
  end
end
