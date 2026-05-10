class ListCustomersTool < ApplicationTool
  description "List customers with their custom attributes and active subscription summary."

  def self.call(server_context:)
    customers = Customer.includes(:subscriptions).order(:name).map do |c|
      {
        id:                  c.id,
        name:                c.name,
        anonymized_label:    c.anonymized_label,
        stripe_customer_id:  c.stripe_customer_id,
        custom_attributes:   c.custom_attributes,
        active_mrr_cents:    c.subscriptions.select { |s| %w[active trialing].include?(s.status) }.sum(&:mrr_cents),
        subscriptions_count: c.subscriptions.size
      }
    end
    json(customers: customers)
  end
end
