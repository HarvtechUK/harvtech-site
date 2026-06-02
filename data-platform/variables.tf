variable "location" {
  description = "Azure region for all resources in this stack."
  type        = string
  default     = "uksouth"
}

variable "project" {
  description = "Project name used in resource naming."
  type        = string
  default     = "harvtech"
}

variable "environment" {
  description = "Environment short name. Drives prd.tfvars selection too."
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags applied to every resource managed by this stack."
  type        = map(string)
  default = {
    project     = "harvtech-data-platform"
    managed_by  = "terraform"
    repo        = "HarvtechUK/harvtech-site"
    cost_centre = "personal"
  }
}

# --- Values driven by env/prd.tfvars ---

variable "lakehouse_layers" {
  description = <<-EOT
    ADLS Gen2 container names. Conventional medallion-architecture
    layout: raw (bronze) holds source data verbatim, cleansed (silver)
    holds validated/typed records, curated (gold) holds business-ready
    aggregates. Drives a for_each over the containers.
  EOT
  type        = list(string)
}

variable "cosmos_databases" {
  description = <<-EOT
    Cosmos DB databases + their containers, keyed by database name.
    Containers are nested with partition_key_path mandatory. Adding
    a new database = one map entry.
  EOT
  type = map(object({
    containers = map(object({
      partition_key_path = string
    }))
  }))
}

variable "enable_cosmos_free_tier" {
  description = <<-EOT
    Enables Cosmos DB free-tier discount: 1000 RU/s + 25GB storage
    free for life on this single account. Microsoft restricts this to
    ONE account per subscription, and it's only assignable at account
    create time. If this subscription has ever had a free-tier Cosmos
    account on a different name, Terraform apply will fail — flip this
    to false and use serverless mode instead.
  EOT
  type        = bool
  default     = true
}

variable "databricks_sku" {
  description = <<-EOT
    Databricks workspace pricing tier. 'standard' is enough for the
    portfolio demo (workspace itself is free; compute is what costs).
    'premium' unlocks Unity Catalog and fine-grained access controls
    which aren't needed without real users.
  EOT
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium", "trial"], var.databricks_sku)
    error_message = "databricks_sku must be one of: standard, premium, trial."
  }
}
