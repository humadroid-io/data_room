class ListInvestorsTool < ApplicationTool
  description "List investors with their access status. Does not return password hashes."

  def self.call(server_context:)
    investors = Investor.order(:name).map do |i|
      {
        id:                i.id,
        name:              i.name,
        fund_name:         i.fund_name,
        email:             i.email,
        active:            i.active,
        access_expires_at: i.access_expires_at&.iso8601,
        last_login_at:     i.last_login_at&.iso8601
      }
    end
    json(investors: investors)
  end
end
