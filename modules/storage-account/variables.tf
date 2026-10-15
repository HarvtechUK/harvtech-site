variable "name" {
  description = "Storage account name. Must follow the CAF convention (st…, compact), which modules/naming produces."
  type        = string

  validation {
    condition     = can(regex("^st[a-z0-9]{1,22}$", var.name))
    error_message = "name must start with \"st\" and be 3-24 lowercase letters and digits in total (Azure allows no hyphens). Use module.naming.storage_account."
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
  description = "Regions this module will deploy to, in Azure's short form. UK only by default, matching modules/resource-group."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

variable "tags" {
  description = "Tags for the account, normally module.tags.tags. Must contain every key in required_tag_keys."
  type        = map(string)

  validation {
    condition     = alltrue([for key in var.required_tag_keys : contains(keys(var.tags), key)])
    error_message = "tags is missing one or more required keys (see required_tag_keys). Pass module.tags.tags rather than a hand-built map."
  }
}

variable "required_tag_keys" {
  description = "Tag keys the account must carry. Defaults to the ownership and cost keys modules/tags emits."
  type        = list(string)
  default     = ["project", "workload", "environment", "owner", "cost_centre", "managed_by"]
}

# --- Trade-offs: safe defaults, explicit overrides -----------------------

variable "replication_type" {
  description = "Redundancy. Defaults to ZRS (survives a zone outage). LRS is cheaper and fine when the data can be rebuilt from source; choosing it should be a visible decision at the call site."
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of LRS, ZRS, GRS, GZRS, RAGRS, RAGZRS."
  }
}

variable "public_network_access_enabled" {
  description = "Whether the account accepts traffic from public networks at all. Off by default. Turn it on deliberately, for example when the consumer (such as Front Door Standard) cannot reach the account privately."
  type        = bool
  default     = false
}

variable "network_rules" {
  description = <<-EOT
    Optional firewall for public traffic. When set, the default action is
    Deny and only the listed IP ranges and subnets get in. Trusted Azure
    services (backup, monitoring, Defender) always bypass it.
  EOT
  type = object({
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default = null

  validation {
    condition     = var.network_rules == null || var.public_network_access_enabled
    error_message = "network_rules filters public traffic, so it only makes sense with public_network_access_enabled = true."
  }
}

variable "hierarchical_namespace_enabled" {
  description = "Enable the hierarchical namespace, which makes the account ADLS Gen2 (data lake) rather than plain blob storage. Can only be set at creation."
  type        = bool
  default     = false
}

variable "blob_soft_delete_retention_days" {
  description = "Days a deleted or overwritten blob can be recovered."
  type        = number
  default     = 7

  validation {
    condition     = var.blob_soft_delete_retention_days >= 1 && var.blob_soft_delete_retention_days <= 365
    error_message = "blob_soft_delete_retention_days must be between 1 and 365."
  }
}

variable "container_soft_delete_retention_days" {
  description = "Days a deleted container can be recovered."
  type        = number
  default     = 7

  validation {
    condition     = var.container_soft_delete_retention_days >= 1 && var.container_soft_delete_retention_days <= 365
    error_message = "container_soft_delete_retention_days must be between 1 and 365."
  }
}

# --- Optional features --------------------------------------------------

variable "static_website" {
  description = "Serve a static website from the $web container. null (the default) leaves it off."
  type = object({
    index_document     = optional(string, "index.html")
    error_404_document = optional(string, "404.html")
  })
  default = null
}

variable "containers" {
  description = "Names of private blob containers to create. Public containers are impossible by design: anonymous blob access is disabled at the account."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for container in var.containers :
      length(container) >= 3 && length(container) <= 63 &&
      can(regex("^[a-z0-9](?:[a-z0-9]|-[a-z0-9])+$", container))
    ])
    error_message = "Container names must be 3-63 lowercase letters, digits and single hyphens, starting and ending with a letter or digit."
  }
}

variable "role_assignments" {
  description = <<-EOT
    Role assignments scoped to the account, keyed by a stable label.
    Shared keys are disabled, so data-plane access is Entra ID only, and
    this is the place to grant it (for example "Storage Blob Data Reader"
    to an app's managed identity). role_definition_id_or_name takes a
    built-in role name or a full role definition ID (starting with "/").
    Owner, User Access Administrator and Role Based Access Control
    Administrator are refused: standing privileged access belongs in PIM.
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
