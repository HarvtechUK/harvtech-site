variable "project" {
  description = "Project short name. Lowercase alphanumeric only — it is embedded in compact names (storage accounts) that forbid hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.project))
    error_message = "project must be lowercase alphanumeric (no hyphens — it feeds compact names like storage accounts)."
  }
}

variable "workload" {
  description = "Workload / stack short name (e.g. site, data, dns). Lowercase alphanumeric only, same compact-name constraint as project."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.workload))
    error_message = "workload must be lowercase alphanumeric (no hyphens)."
  }
}

variable "environment" {
  description = "Environment short code. Matches the env/<code>.tfvars convention used by every stack in this repo."
  type        = string

  validation {
    condition     = contains(["dev", "tst", "stg", "prd"], var.environment)
    error_message = "environment must be one of: dev, tst, stg, prd."
  }
}

variable "location" {
  description = "Azure region long name. Mapped to the short code used in names (uksouth -> uks). Extend the region_short map in main.tf to support more regions."
  type        = string
  default     = "uksouth"

  validation {
    condition     = contains(["uksouth", "ukwest", "northeurope", "westeurope"], var.location)
    error_message = "location must be one of the regions in the module's region_short map: uksouth, ukwest, northeurope, westeurope."
  }
}

variable "ordinal" {
  description = "Two-digit instance ordinal appended to every name. Lets a second instance of the same resource type coexist (…-uks-01, …-uks-02)."
  type        = string
  default     = "01"

  validation {
    condition     = can(regex("^[0-9]{2}$", var.ordinal))
    error_message = "ordinal must be exactly two digits (e.g. 01)."
  }
}
