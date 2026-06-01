output "ca_policy_ids" {
  value = {
    require_mfa_all_users        = azuread_conditional_access_policy.require_mfa_all_users.id
    block_legacy_auth            = azuread_conditional_access_policy.block_legacy_auth.id
    admin_phishing_resistant_mfa = azuread_conditional_access_policy.admin_phishing_resistant_mfa.id
    geo_block                    = azuread_conditional_access_policy.geo_block.id
    admin_signin_frequency       = azuread_conditional_access_policy.admin_signin_frequency.id
  }
  description = "Object IDs of the CA policies created by this stack — useful for cross-referencing with Entra sign-in logs."
}

output "allowed_countries_location_id" {
  value       = azuread_named_location.allowed_countries.id
  description = "ID of the 'Allowed countries' Named Location."
}

output "break_glass_object_id" {
  value       = data.azuread_user.break_glass.object_id
  description = "Object ID of the break-glass account — every CA policy excludes this principal."
}

output "policy_state" {
  value       = var.policy_state
  description = "Current enforcement state of all policies in this stack."
}
