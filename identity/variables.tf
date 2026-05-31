variable "tenant_id" {
  description = "Entra tenant ID. Defaults to the tenant the SP is federated against."
  type        = string
  default     = "f180423f-2b59-49dd-9319-7c35c1f3e6a4"
}

variable "break_glass_upn" {
  description = "User principal name of the break-glass account. EXCLUDED from every CA policy in this stack so a misconfigured rule can never lock out the tenant."
  type        = string
  default     = "breakglass@marvtec.onmicrosoft.com"
}

variable "allowed_country_codes" {
  description = "ISO-3166 alpha-2 country codes for the 'allowed countries' Named Location. Sign-ins from outside this list are blocked by the geo-block CA policy."
  type        = list(string)
  default     = ["GB"]
}

variable "policy_state" {
  description = "Initial state for every CA policy this stack creates. 'enabledForReportingButNotEnforced' = log-only (safe default). Flip to 'enabled' in a later commit once sign-in logs confirm no surprises."
  type        = string
  default     = "enabledForReportingButNotEnforced"

  validation {
    condition     = contains(["enabled", "enabledForReportingButNotEnforced", "disabled"], var.policy_state)
    error_message = "policy_state must be one of: enabled, enabledForReportingButNotEnforced, disabled."
  }
}
