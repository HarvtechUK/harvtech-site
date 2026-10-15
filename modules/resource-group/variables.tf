variable "name" {
  description = "Resource group name. Must follow the CAF convention (rg-…), which modules/naming produces."
  type        = string

  validation {
    condition     = startswith(var.name, "rg-")
    error_message = "name must start with the CAF abbreviation \"rg-\". Use module.naming.resource_group."
  }

  validation {
    condition     = length(var.name) <= 90 && can(regex("^[-\\w.()]+$", var.name)) && !endswith(var.name, ".")
    error_message = "name must be at most 90 characters of letters, digits, underscores, hyphens, periods and parentheses, and must not end with a period (Azure resource group rules)."
  }
}

variable "location" {
  description = "Azure region for the resource group. Must be in allowed_locations."
  type        = string

  validation {
    condition     = contains(var.allowed_locations, lower(replace(var.location, " ", "")))
    error_message = "location is outside allowed_locations. The default allows UK regions only (data residency); widen allowed_locations deliberately if a workload genuinely needs another region."
  }
}

variable "allowed_locations" {
  description = "Regions this module will deploy to, in Azure's short form (uksouth, not UK South). Defaults to UK only, because regulated UK clients usually need data to stay in the UK and a typo should not quietly put a workload in eastus."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

variable "tags" {
  description = "Tags for the resource group, normally module.tags.tags. Must contain every key in required_tag_keys."
  type        = map(string)

  validation {
    condition     = alltrue([for key in var.required_tag_keys : contains(keys(var.tags), key)])
    error_message = "tags is missing one or more required keys (see required_tag_keys). Pass module.tags.tags rather than a hand-built map."
  }
}

variable "required_tag_keys" {
  description = "Tag keys every resource group must carry. Defaults to the ownership and cost keys modules/tags emits, so an untagged or half-tagged resource group fails at plan time instead of surfacing later in a cost report."
  type        = list(string)
  default     = ["project", "workload", "environment", "owner", "cost_centre", "managed_by"]
}

variable "lock" {
  description = <<-EOT
    Optional management lock on the resource group. kind is CanNotDelete
    or ReadOnly; name and notes have sensible defaults. Creating a lock
    needs Microsoft.Authorization/locks/write (Owner or User Access
    Administrator), which a Contributor-only deployment identity lacks.
    A CanNotDelete lock also blocks Terraform from deleting or replacing
    resources inside the group, so plan replacements accordingly.
  EOT
  type = object({
    kind  = string
    name  = optional(string)
    notes = optional(string)
  })
  default = null

  validation {
    condition     = var.lock == null || contains(["CanNotDelete", "ReadOnly"], try(var.lock.kind, ""))
    error_message = "lock.kind must be CanNotDelete or ReadOnly."
  }
}

variable "role_assignments" {
  description = <<-EOT
    Role assignments scoped to the resource group, keyed by a stable
    label (the key becomes part of the Terraform address, so do not
    rename it casually). role_definition_id_or_name takes either a
    built-in role name ("Reader") or a full role definition ID
    (starting with "/"). Privileged roles (Owner, User Access
    Administrator, Role Based Access Control Administrator) are refused:
    standing privileged access belongs in PIM as an eligible assignment,
    not in a permanent grant.
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
      assignment.principal_type == null || contains(["User", "Group", "ServicePrincipal", "ForeignGroup", "Device"], coalesce(assignment.principal_type, "User"))
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
