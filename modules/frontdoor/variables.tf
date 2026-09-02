variable "resource_group_name" {
  description = "Resource group the Front Door profile (and its WAF policy) live in."
  type        = string
}

variable "profile_name" {
  description = "Front Door profile name (afd-… from modules/naming)."
  type        = string
}

variable "sku_name" {
  description = "Front Door SKU. Standard supports custom WAF rules only; Microsoft-managed rulesets (DRS, Bot Manager) and Private Link to origin require Premium (~£200/mo uplift)."
  type        = string
  default     = "Standard_AzureFrontDoor"

  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.sku_name)
    error_message = "sku_name must be Standard_AzureFrontDoor or Premium_AzureFrontDoor."
  }
}

variable "endpoint_name" {
  description = "Endpoint name — becomes the <name>-<hash>.z01.azurefd.net hostname."
  type        = string
}

variable "origin_group_name" {
  description = "Origin group name (Front Door-internal)."
  type        = string
}

variable "origin_name" {
  description = "Origin name (Front Door-internal)."
  type        = string
}

variable "origin_host_name" {
  description = "Hostname of the origin (e.g. a storage account's primary_web_host). Also used as the origin host header, which static-website origins require."
  type        = string
}

variable "route_name" {
  description = "Name of the default catch-all route."
  type        = string
}

variable "custom_domains" {
  description = <<-EOT
    Custom domains keyed by a stable short name (apex / www / …). The key
    becomes the Terraform address suffix — keep it stable across renames
    or the domain is destroyed and re-created, re-triggering the
    validation TXT dance. `name` is the Azure resource name (lowercase,
    hyphens); `host_name` the actual FQDN.
  EOT
  type = map(object({
    host_name = string
    name      = string
  }))
}

variable "www_to_apex_redirect" {
  description = "Optional 301 redirect from a www hostname to the apex, via the rules engine. null = no redirect rule set is created."
  type = object({
    rule_set_name = string
    rule_name     = string
    www_hostname  = string
    apex_hostname = string
  })
  default = null
}

# --- WAF (deliberately NOT optional) ---
# This module refuses to create an unprotected Front Door: every instance
# gets a firewall policy bound to all its custom domains. If a consumer
# genuinely wants no rules, they can pass an empty block_rules list — but
# the rate limit still applies.

variable "waf_policy_name" {
  description = "WAF policy name (letters and numbers only — Azure rejects hyphens here)."
  type        = string
}

variable "waf_security_policy_name" {
  description = "Name of the security policy that binds the WAF to the custom domains."
  type        = string
}

variable "waf_mode" {
  description = "Prevention blocks matching requests; Detection only logs them — the fast escape hatch if a rule false-positives."
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Prevention", "Detection"], var.waf_mode)
    error_message = "waf_mode must be Prevention or Detection."
  }
}

variable "waf_block_rules" {
  description = <<-EOT
    "Block this path if it contains any of these strings" rules, iterated
    via a dynamic block. Priorities must be unique; convention is 10s so
    new rules slot between without renumbering.
  EOT
  type = list(object({
    name         = string
    priority     = number
    description  = optional(string, "")
    match_values = list(string)
  }))
}

variable "waf_rate_limit" {
  description = "Per-client-IP rate limit: requests per minute before blocking. Hard for a human to hit; throttles simple scrapers and brute-forcers."
  type = object({
    name      = string
    threshold = number
    priority  = optional(number, 100)
  })
}

variable "tags" {
  description = "Tags for the taggable resources (profile, endpoint, WAF policy)."
  type        = map(string)
}
