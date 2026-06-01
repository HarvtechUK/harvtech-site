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

# Values for the two variables below live in terraform.tfvars — keeping
# the role-template ID lists as config (rather than constants in code)
# means tightening or relaxing CA scope is a tfvars edit, not a
# resource-code change.

variable "phishing_resistant_admin_roles" {
  description = "Entra role-template IDs whose holders must use phishing-resistant MFA (drives CA003)."
  type        = list(string)
}

variable "frequent_reauth_admin_roles" {
  description = "Entra role-template IDs whose holders are forced to re-auth every var.policy_state-defined interval (drives CA005). Typically a tighter subset of phishing_resistant_admin_roles."
  type        = list(string)
}
