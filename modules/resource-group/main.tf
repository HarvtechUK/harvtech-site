# A resource group with the house rules applied: UK regions by default,
# mandatory ownership and cost tags, an optional management lock, and
# role assignments that refuse standing privileged access.
#
# The interface (lock, role_assignments with role_definition_id_or_name)
# deliberately mirrors Azure Verified Modules, so swapping this for
# Azure/avm-res-resources-resourcegroup later is a source change rather
# than a rewrite.

locals {
  # Built-in roles that can grant or escalate access. GUIDs are fixed
  # across every Azure tenant, so matching on them also catches a full
  # role definition ID passed instead of the name.
  privileged_roles = [
    { name = "Owner", guid = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635" },
    { name = "User Access Administrator", guid = "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9" },
    { name = "Role Based Access Control Administrator", guid = "f58310d9-a9f6-439a-9e8d-f62e7b41a168" },
  ]
}

resource "azurerm_resource_group" "workload" {
  name     = var.name
  location = var.location
  tags     = var.tags
}

resource "azurerm_management_lock" "workload" {
  count = var.lock == null ? 0 : 1

  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_resource_group.workload.id
  lock_level = var.lock.kind
  notes      = coalesce(var.lock.notes, "Managed by Terraform. Remove through code, not the portal.")
}

resource "azurerm_role_assignment" "workload" {
  for_each = var.role_assignments

  scope = azurerm_resource_group.workload.id

  # A leading "/" means a full role definition ID; anything else is a
  # built-in role name. Exactly one of the two is ever set.
  role_definition_id   = startswith(each.value.role_definition_id_or_name, "/") ? each.value.role_definition_id_or_name : null
  role_definition_name = startswith(each.value.role_definition_id_or_name, "/") ? null : each.value.role_definition_id_or_name

  principal_id                     = each.value.principal_id
  principal_type                   = each.value.principal_type
  description                      = each.value.description
  condition                        = each.value.condition
  condition_version                = each.value.condition_version
  skip_service_principal_aad_check = each.value.skip_service_principal_aad_check
}
