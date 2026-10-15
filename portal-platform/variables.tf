variable "location" {
  description = "Azure region for all resources in this stack."
  type        = string
  default     = "uksouth"
}

variable "project" {
  description = "Project short name used in resource naming."
  type        = string
  default     = "harvtech"
}

variable "environment" {
  description = "Environment short code. Matches the env/<code>.tfvars convention used by the other stacks."
  type        = string
  default     = "prd"
}

variable "portal_containers" {
  description = <<-EOT
    Cosmos SQL containers for the portal database, keyed by container
    name with their partition key path. Partition keys must start with a
    leading slash. engagements/timesheets are partitioned by /clientId
    for per-tenant isolation; clients/users by /id. Adding a container is
    a tfvars edit.
  EOT
  type = map(object({
    partition_key_path = string
  }))
}

variable "portal_entra_client_id" {
  description = "Application (client) ID of the multi-tenant \"HarvTech Client Portal\" Entra app. A public identifier, not a secret: it appears in every sign-in redirect."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.portal_entra_client_id))
    error_message = "portal_entra_client_id must be a GUID."
  }
}
