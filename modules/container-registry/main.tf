# A container registry that only identities can use: no admin user, no
# anonymous pulls. Images are pulled by managed identities with AcrPull
# and pushed by CI with AcrPush, granted through role_assignments.
#
# Defaults to Premium and private. Cheaper tiers are an explicit choice
# at the call site, and the module refuses combinations Azure would
# reject (a private Basic registry) at plan time instead of mid-apply.

locals {
  # Built-in roles that can grant or escalate access. GUIDs are fixed
  # across every Azure tenant, so matching on them also catches a full
  # role definition ID passed instead of the name.
  privileged_roles = [
    { name = "Owner", guid = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635" },
    { name = "User Access Administrator", guid = "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9" },
    { name = "Role Based Access Control Administrator", guid = "f58310d9-a9f6-439a-9e8d-f62e7b41a168" },
  ]

  premium = var.sku == "Premium"
}

resource "azurerm_container_registry" "workload" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  tags                = var.tags

  public_network_access_enabled = var.public_network_access_enabled

  # --- Security baseline (not configurable) ---

  # The admin user is a single shared username/password with push and
  # pull rights. Identities with AcrPull/AcrPush replace it entirely.
  admin_enabled = false

  # Pulls always need an identity.
  anonymous_pull_enabled = false

  # Premium only: clear out superseded, untagged layers.
  retention_policy_in_days = local.premium ? var.untagged_retention_days : null

  lifecycle {
    precondition {
      condition     = var.public_network_access_enabled || local.premium
      error_message = "Only Premium registries can disable public network access. Use sku = \"Premium\" or set public_network_access_enabled = true."
    }
  }
}

resource "azurerm_role_assignment" "workload" {
  for_each = var.role_assignments

  scope = azurerm_container_registry.workload.id

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
