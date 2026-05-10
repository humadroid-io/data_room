require "test_helper"

class McpEndpointTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:user, role: :admin)
    @admin.regenerate_api_token!
  end

  def jsonrpc(payload, token: @admin.api_token)
    headers = {
      "Content-Type"  => "application/json",
      "Accept"        => "application/json, text/event-stream"
    }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: payload.to_json, headers: headers
  end

  test "rejects request without Bearer token" do
    jsonrpc({ jsonrpc: "2.0", id: 1, method: "tools/list" }, token: nil)
    assert_response :unauthorized
  end

  test "rejects request with invalid token" do
    jsonrpc({ jsonrpc: "2.0", id: 1, method: "tools/list" }, token: "dr_nope")
    assert_response :unauthorized
  end

  test "tools/list returns the registered tools" do
    jsonrpc({ jsonrpc: "2.0", id: 1, method: "tools/list" })
    assert_response :success
    body = response.body
    assert_includes body, "list_pages_tool"
    assert_includes body, "create_page_tool"
    assert_includes body, "update_page_tool"
    assert_includes body, "set_page_visibility_tool"
  end

  test "tools/call create_page_tool persists a page" do
    jsonrpc({
      jsonrpc: "2.0", id: 2, method: "tools/call",
      params: {
        name: "create_page_tool",
        arguments: { title: "From MCP", slug: "from-mcp", visibility: "public" }
      }
    })
    assert_response :success
    assert Page.exists?(path: "/from-mcp")
  end
end
