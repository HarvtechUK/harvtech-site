output "id" {
  description = "Registry ID, for scoping role assignments."
  value       = azurerm_container_registry.workload.id
}

output "name" {
  description = "Registry name, for CLI calls (az acr build --registry …)."
  value       = azurerm_container_registry.workload.name
}

output "login_server" {
  description = "Login server (<name>.azurecr.io), for image references and a Container App's registry block."
  value       = azurerm_container_registry.workload.login_server
}

output "role_assignment_ids" {
  description = "Role assignment IDs keyed the same way as var.role_assignments."
  value       = { for key, assignment in azurerm_role_assignment.workload : key => assignment.id }
}
