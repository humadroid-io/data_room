def seed_attribute(resource_type:, key:, label:, data_type:, sort_order:,
                   required: false, capture_on_snapshot: false, options: [])
  defn = AttributeDefinition.find_or_initialize_by(resource_type: resource_type, key: key)
  defn.label               = label
  defn.data_type           = data_type
  defn.required            = required
  defn.capture_on_snapshot = capture_on_snapshot
  defn.sort_order          = sort_order
  defn.save!

  options.each_with_index do |opt, idx|
    row = defn.attribute_options.find_or_initialize_by(value: opt[:value])
    row.label      = opt[:label]
    row.color      = opt[:color]
    row.sort_order = idx
    row.save!
  end
end

seed_attribute(
  resource_type: "Customer", key: "compliance_stage", label: "Compliance stage",
  data_type: :single_select, sort_order: 1,
  required: true, capture_on_snapshot: true,
  options: [
    { value: "onboarding",     label: "Onboarding",     color: "neutral" },
    { value: "implementation", label: "Implementation", color: "info" },
    { value: "audit_ready",    label: "Audit-ready",    color: "warning" },
    { value: "in_audit",       label: "In audit",       color: "warning" },
    { value: "certified",      label: "Certified",      color: "success" },
    { value: "on_hold",        label: "On hold",        color: "error" }
  ]
)

seed_attribute(
  resource_type: "Customer", key: "frameworks", label: "Frameworks",
  data_type: :multi_select, sort_order: 2,
  options: [
    { value: "soc2",     label: "SOC 2",     color: "info" },
    { value: "iso27001", label: "ISO 27001", color: "secondary" },
    { value: "hipaa",    label: "HIPAA",     color: "success" }
  ]
)

seed_attribute(
  resource_type: "Customer", key: "auditor", label: "Auditor",
  data_type: :single_select, sort_order: 3,
  options: [
    { value: "internal", label: "Internal", color: "success" },
    { value: "external", label: "External", color: "neutral" },
    { value: "tbd",      label: "TBD",      color: "neutral" }
  ]
)

seed_attribute(
  resource_type: "Customer", key: "audit_scheduled", label: "Audit scheduled",
  data_type: :date, sort_order: 4
)

seed_attribute(
  resource_type: "Customer", key: "cert_delivered", label: "Cert delivered",
  data_type: :date, sort_order: 5
)

seed_attribute(
  resource_type: "Customer", key: "industry", label: "Industry",
  data_type: :single_select, sort_order: 6,
  options: [
    { value: "heavy_saas",          label: "Heavy SaaS",          color: "info" },
    { value: "critical_path_tools", label: "Critical-path tools", color: "warning" },
    { value: "ai_saas",             label: "AI SaaS",             color: "secondary" },
    { value: "other",               label: "Other",               color: "neutral" }
  ]
)

seed_attribute(
  resource_type: "Customer", key: "acquired_via", label: "Acquired via",
  data_type: :single_select, sort_order: 7,
  options: [
    { value: "reddit",         label: "Reddit",         color: "error" },
    { value: "linkedin",       label: "LinkedIn",       color: "info" },
    { value: "network",        label: "Network",        color: "success" },
    { value: "community",      label: "Community",      color: "secondary" },
    { value: "email_outbound", label: "Email outbound", color: "neutral" },
    { value: "other",          label: "Other",          color: "neutral" }
  ]
)

seed_attribute(
  resource_type: "Customer", key: "team_size", label: "Team size",
  data_type: :integer, sort_order: 8
)
