output "id" {
  description = "Resource group ID, for scoping role assignments, policy assignments and budgets."
  value       = azurerm_resource_group.workload.id
}

output "name" {
  description = "Resource group name, for the resource_group_name argument of resources deployed into it."
  value       = azurerm_resource_group.workload.name
}

output "location" {
  description = "Resource group region in Azure's short form (uksouth), for co-locating the resources inside it."
  value       = azurerm_resource_group.workload.location
}

output "lock_id" {
  description = "Management lock ID, or null when no lock is configured."
  value       = one(azurerm_management_lock.workload[*].id)
}

output "role_assignment_ids" {
  description = "Role assignment IDs keyed the same way as var.role_assignments."
  value       = { for key, assignment in azurerm_role_assignment.workload : key => assignment.id }
}
