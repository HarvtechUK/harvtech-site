variable "location" {
  description = "Azure region"
  type        = string
  default     = "uksouth"
}

variable "project" {
  description = "Project name, used in resource naming"
  type        = string
  default     = "harvtech"
}

variable "environment" {
  description = "Environment short code. Matches the env/<code>.tfvars convention and the platform bootstrap naming (rg-platform-prd-uks-01)."
  type        = string
  default     = "prd"
}

# --- Inputs driving the for_each loops; values live in terraform.tfvars ---

variable "custom_domains" {
  description = <<-EOT
    Front Door custom domains keyed by a stable short name. The key
    becomes the Terraform address suffix — keep it stable across
    renames or Terraform will see it as a destroy/create. Adding a
    domain = adding a map entry; no resource code change needed.
  EOT
  type = map(object({
    host_name = string
    name      = string # Azure resource name (lowercase, hyphens only)
  }))
}

variable "waf_block_rules" {
  description = <<-EOT
    "Block this path if it contains any of these strings" rules for
    the WAF policy. Same shape across all entries — iterated via a
    dynamic block in waf.tf. Priorities must be unique; convention
    is to keep them in 10s so new ones slot between without renumbering.
  EOT
  type = list(object({
    name         = string
    priority     = number
    description  = optional(string, "")
    match_values = list(string)
  }))
}
