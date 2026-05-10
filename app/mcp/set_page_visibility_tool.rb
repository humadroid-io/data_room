class SetPageVisibilityTool < ApplicationTool
  description <<~DESC
    Add or remove an investor from a private page's allowlist. The page must
    already have visibility=private; for public/draft pages this is a no-op
    (use update_page_tool to change visibility).
  DESC

  input_schema(
    properties: {
      page_id:        { type: "integer" },
      page_path:      { type: "string" },
      investor_id:    { type: "integer" },
      investor_email: { type: "string" },
      allowed:        { type: "boolean", description: "true grants access, false revokes." }
    },
    required: [ "allowed" ]
  )

  def self.call(page_id: nil, page_path: nil, investor_id: nil, investor_email: nil,
                allowed:, server_context:)
    page = Page.find_by(id: page_id) if page_id
    page ||= Page.find_by(path: page_path) if page_path
    return error("Page not found") unless page
    return error("Page is not private; change visibility via update_page_tool first.") unless page.visibility_private?

    investor = Investor.find_by(id: investor_id) if investor_id
    investor ||= Investor.find_by(email: investor_email) if investor_email
    return error("Investor not found") unless investor

    if allowed
      page.page_accesses.find_or_create_by!(investor: investor)
      text("Granted #{investor.email || investor.name} access to '#{page.path}'.")
    else
      page.page_accesses.where(investor: investor).destroy_all
      text("Revoked access to '#{page.path}' from #{investor.email || investor.name}.")
    end
  end
end
