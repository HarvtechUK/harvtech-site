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

variable "portal_hostname" {
  description = "Custom domain the portal is served on. Bound to the Static Web App as a custom domain; the matching CNAME is created by the dns/ stack from this stack's remote state."
  type        = string
  default     = "portal.harvtech.co.uk"
}

variable "static_web_app_sku" {
  description = "Static Web App SKU. Standard is required for a linked (bring-your-own) Function App backend — Free only supports SWA-managed Functions, which can't use a managed identity to our Cosmos account."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard"], var.static_web_app_sku)
    error_message = "static_web_app_sku must be Free or Standard."
  }
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
