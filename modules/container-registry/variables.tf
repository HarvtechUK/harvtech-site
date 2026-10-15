variable "name" {
  description = "Registry name. Must follow the CAF convention (cr…, compact), which modules/naming produces."
  type        = string

  validation {
    condition     = can(regex("^cr[a-zA-Z0-9]{3,48}$", var.name))
    error_message = "name must start with \"cr\" and be 5-50 letters and digits in total (Azure allows no hyphens). Use module.naming.container_registry."
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
  description = "Tags for the registry, normally module.tags.tags. Must contain every key in required_tag_keys."
  type        = map(string)

  validation {
    condition     = alltrue([for key in var.required_tag_keys : contains(keys(var.tags), key)])
    error_message = "tags is missing one or more required keys (see required_tag_keys). Pass module.tags.tags rather than a hand-built map."
  }
}

variable "required_tag_keys" {
  description = "Tag keys the registry must carry. Defaults to the ownership and cost keys modules/tags emits."
  type        = list(string)
  default     = ["project", "workload", "environment", "owner", "cost_centre", "managed_by"]
}

# --- Trade-offs: safe defaults, explicit overrides -----------------------

variable "sku" {
  description = "Registry tier. Defaults to Premium, the only tier that supports private access and untagged-manifest retention. Basic (~£4/mo) is fine for a small first-party registry; choosing it should be a visible decision at the call site."
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard or Premium."
  }
}

variable "public_network_access_enabled" {
  description = "Whether the registry is reachable from public networks. Off by default. Only Premium can turn it off, so Basic and Standard registries must set this to true."
  type        = bool
  default     = false
}

variable "untagged_retention_days" {
  description = "Premium only: days before untagged manifests (superseded image layers) are deleted. Ignored on other tiers."
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_retention_days >= 1 && var.untagged_retention_days <= 365
    error_message = "untagged_retention_days must be between 1 and 365."
  }
}

# --- Optional features --------------------------------------------------

variable "role_assignments" {
  description = <<-EOT
    Role assignments scoped to the registry, keyed by a stable label.
    The admin user is disabled, so this is how anything pulls or pushes:
    AcrPull for an app's managed identity, AcrPush for a CI identity.
    role_definition_id_or_name takes a built-in role name or a full role
    definition ID (starting with "/"). Owner, User Access Administrator
    and Role Based Access Control Administrator are refused: standing
    privileged access belongs in PIM.
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
