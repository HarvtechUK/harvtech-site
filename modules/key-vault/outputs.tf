output "id" {
  description = "Key vault ID, for scoping role assignments."
  value       = azurerm_key_vault.workload.id
}

output "name" {
  description = "Key vault name, for CLI calls (az keyvault secret set --vault-name …)."
  value       = azurerm_key_vault.workload.name
}

output "vault_uri" {
  description = "Vault URI (https://<name>.vault.azure.net/). Versionless secret IDs are \"<vault_uri>secrets/<name>\"."
  value       = azurerm_key_vault.workload.vault_uri
}

output "role_assignment_ids" {
  description = "Role assignment IDs keyed the same way as var.role_assignments."
  value       = { for key, assignment in azurerm_role_assignment.workload : key => assignment.id }
}
