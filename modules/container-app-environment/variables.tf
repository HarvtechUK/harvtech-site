variable "name" {
  description = "Environment name. Must follow the CAF convention (cae-…), which modules/naming produces."
  type        = string

  validation {
    condition     = can(regex("^cae-[a-z0-9-]{1,56}[a-z0-9]$", var.name)) && !strcontains(var.name, "--")
    error_message = "name must start with \"cae-\", be at most 60 lowercase letters, digits and single hyphens, and end with a letter or digit. Use module.naming.container_app_environment."
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
  description = "Tags for the environment, normally module.tags.tags. Must contain every key in required_tag_keys."
  type        = map(string)

  validation {
    condition     = alltrue([for key in var.required_tag_keys : contains(keys(var.tags), key)])
    error_message = "tags is missing one or more required keys (see required_tag_keys). Pass module.tags.tags rather than a hand-built map."
  }
}

variable "required_tag_keys" {
  description = "Tag keys the environment must carry. Defaults to the ownership and cost keys modules/tags emits."
  type        = list(string)
  default     = ["project", "workload", "environment", "owner", "cost_centre", "managed_by"]
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace that receives every app's stdout/stderr and system logs. Required: an environment whose logs go nowhere cannot be investigated."
  type        = string
}

# --- Optional features --------------------------------------------------

variable "infrastructure_subnet_id" {
  description = "Subnet for VNet integration (a dedicated /23 or larger for the Consumption plan). null runs the environment on Microsoft-managed networking, which is why its apps can only reach public endpoints."
  type        = string
  default     = null
}

variable "internal_load_balancer_enabled" {
  description = "Expose apps on a private IP inside the VNet only. Requires infrastructure_subnet_id."
  type        = bool
  default     = false
}
