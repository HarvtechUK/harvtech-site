variable "name" {
  description = "Key vault name. Must follow the CAF convention (kv…), which modules/naming produces."
  type        = string

  validation {
    condition     = can(regex("^kv[a-zA-Z0-9-]{1,22}$", var.name)) && !endswith(var.name, "-") && !strcontains(var.name, "--")
    error_message = "name must start with \"kv\", be 3-24 letters, digits and single hyphens, and not end with a hyphen. Use module.naming.key_vault."
  }
}

variable "resource_group_name" {
  description = "Resource group to deploy into, normally module.resource_group.name."
  type        = string
}

variable "location" {
  description = "Azure region. Must be in allowed_locations."
  type        = string

  validation {
    condition     = contains(var.allowed_locations, lower(replace(var.location, " ", "")))
    error_message = "location is outside allowed_locations. The default allows UK regions only (data residency); widen allowed_locations deliberately if a workload genuinely needs another region."
  }
}

variable "allowed_locations" {
  description = "Regions this module will deploy to, in Azure's short form. UK only by default, matching the other modules."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

variable "tags" {
  description = "Tags for the vault, normally module.tags.tags. Must contain every key in required_tag_keys."
  type        = map(string)

  validation {
    condition     = alltrue([for key in var.required_tag_keys : contains(keys(var.tags), key)])
    error_message = "tags is missing one or more required keys (see required_tag_keys). Pass module.tags.tags rather than a hand-built map."
  }
}

variable "required_tag_keys" {
  description = "Tag keys the vault must carry. Defaults to the ownership and cost keys modules/tags emits."
  type        = list(string)
  default     = ["project", "workload", "environment", "owner", "cost_centre", "managed_by"]
}

variable "tenant_id" {
  description = "Entra tenant that authenticates requests to the vault, normally data.azurerm_client_config.current.tenant_id."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives the vault's audit log (every secret read and write, by whom). Required: a vault without an audit trail cannot answer \"who read this secret?\", which is the first question in any incident."
  type        = string
}

# --- Trade-offs: safe defaults, explicit overrides -----------------------

variable "sku_name" {
  description = "standard, or premium for HSM-backed keys."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be standard or premium."
  }
}

variable "public_network_access_enabled" {
  description = "Whether the vault accepts traffic from public networks at all. Off by default. Turn it on deliberately when a consumer cannot reach it privately (for example a Container Apps environment without VNet integration)."
  type        = bool
  default     = false
}

variable "firewall_ip_rules" {
  description = "Public IP ranges (CIDR) allowed through the firewall. Any rule switches the default action to Deny. Trusted Azure services always bypass."
  type        = list(string)
  default     = []

  # Self-contained check only. The "rules need public access" check is a
  # precondition on the vault in main.tf: Checkov stops resolving a
  # variable whose validation references another variable, and then
  # reports the firewall checks as passed whatever the real value.
  validation {
    condition     = alltrue([for rule in var.firewall_ip_rules : can(cidrhost(strcontains(rule, "/") ? rule : "${rule}/32", 0))])
    error_message = "Each firewall_ip_rules entry must be an IP address or CIDR range."
  }
}

variable "firewall_subnet_ids" {
  description = "Subnets allowed through the firewall (they need the Microsoft.KeyVault service endpoint). Any entry switches the default action to Deny."
  type        = list(string)
  default     = []

}

# --- Optional features --------------------------------------------------

variable "role_assignments" {
  description = <<-EOT
    Role assignments scoped to the vault, keyed by a stable label. The
    vault uses Azure RBAC (no access policies), so this is how anything
    gets access, for example "Key Vault Secrets User" for an app's
    managed identity. role_definition_id_or_name takes a built-in role
    name or a full role definition ID (starting with "/"). Owner, User
    Access Administrator and Role Based Access Control Administrator are
    refused: standing privileged access belongs in PIM.
  EOT
  type = map(object({
    role_definition_id_or_name       = string
    principal_id                     = string
    principal_type                   = optional(string)
    description                      = optional(string)
    condition                        = optional(string)
    condition_version                = optional(string)
    skip_service_principal_aad_check = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) : !anytrue([
        for privileged in local.privileged_roles :
        lower(assignment.role_definition_id_or_name) == lower(privileged.name) ||
        endswith(lower(assignment.role_definition_id_or_name), privileged.guid)
      ])
    ])
    error_message = "role_assignments must not grant Owner, User Access Administrator or Role Based Access Control Administrator. Make privileged access PIM-eligible instead of permanent."
  }

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      contains(["User", "Group", "ServicePrincipal", "ForeignGroup", "Device"], coalesce(assignment.principal_type, "User"))
    ])
    error_message = "principal_type must be User, Group, ServicePrincipal, ForeignGroup or Device."
  }

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) :
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", assignment.principal_id))
    ])
    error_message = "principal_id must be an Entra object ID (a GUID), not a UPN or display name."
  }
}
