AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "compliance_stage") do |a|
  a.label     = "Compliance stage"
  a.data_type = :single_select
  a.options   = [
    { value: "onboarding",     label: "Onboarding",     color: "neutral" },
    { value: "implementation", label: "Implementation", color: "info" },
    { value: "audit_ready",    label: "Audit-ready",    color: "warning" },
    { value: "in_audit",       label: "In audit",       color: "warning" },
    { value: "certified",      label: "Certified",      color: "success" },
    { value: "on_hold",        label: "On hold",        color: "error" }
  ]
  a.required            = true
  a.capture_on_snapshot = true
  a.sort_order          = 1
end

AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "frameworks") do |a|
  a.label     = "Frameworks"
  a.data_type = :multi_select
  a.options   = [
    { value: "soc2",     label: "SOC 2",     color: "info" },
    { value: "iso27001", label: "ISO 27001", color: "secondary" },
    { value: "hipaa",    label: "HIPAA",     color: "success" }
  ]
  a.sort_order = 2
end

AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "auditor") do |a|
  a.label     = "Auditor"
  a.data_type = :single_select
  a.options   = [
    { value: "internal", label: "Internal", color: "success" },
    { value: "external", label: "External", color: "neutral" },
    { value: "tbd",      label: "TBD",      color: "neutral" }
  ]
  a.sort_order = 3
end

AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "audit_scheduled") do |a|
  a.label      = "Audit scheduled"
  a.data_type  = :date
  a.sort_order = 4
end

AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "cert_delivered") do |a|
  a.label      = "Cert delivered"
  a.data_type  = :date
  a.sort_order = 5
end

AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "industry") do |a|
  a.label     = "Industry"
  a.data_type = :single_select
  a.options   = [
    { value: "heavy_saas",          label: "Heavy SaaS",          color: "info" },
    { value: "critical_path_tools", label: "Critical-path tools", color: "warning" },
    { value: "ai_saas",             label: "AI SaaS",             color: "secondary" },
    { value: "other",               label: "Other",               color: "neutral" }
  ]
  a.sort_order = 6
end

AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "acquired_via") do |a|
  a.label     = "Acquired via"
  a.data_type = :single_select
  a.options   = [
    { value: "reddit",         label: "Reddit",         color: "error" },
    { value: "linkedin",       label: "LinkedIn",       color: "info" },
    { value: "network",        label: "Network",        color: "success" },
    { value: "community",      label: "Community",      color: "secondary" },
    { value: "email_outbound", label: "Email outbound", color: "neutral" },
    { value: "other",          label: "Other",          color: "neutral" }
  ]
  a.sort_order = 7
end

AttributeDefinition.find_or_create_by!(resource_type: "Customer", key: "team_size") do |a|
  a.label      = "Team size"
  a.data_type  = :integer
  a.sort_order = 8
end
