# A Key Vault for application secrets, with the security baseline fixed
# in code: Azure RBAC only (no access policies), purge protection, 90-day
# soft delete, no ARM/VM/disk-encryption side doors, and an audit log
# that cannot be left off.
#
# This module deliberately creates no secrets. Anything Terraform writes
# into a vault is also written into Terraform state in plaintext, so
# secret values are set by an operator or a rotation process, and
# Terraform only ever handles references to them (see
# modules/container-app, which accepts Key Vault references and nothing
# else).

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

resource "azurerm_key_vault" "workload" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name
  tags                = var.tags

  public_network_access_enabled = var.public_network_access_enabled

  # --- Security baseline (not configurable) ---

  # Azure RBAC for data-plane access. Access policies are a separate,
  # vault-local permission system that RBAC tooling, PIM and access
  # reviews cannot see.
  rbac_authorization_enabled = true

  # A deleted vault or secret is recoverable for 90 days, and purge
  # protection stops anyone (including an attacker with Owner) from
  # skipping that window. Note: purge protection cannot be turned off,
  # and a deleted vault's name stays reserved until the window ends.
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  # Side doors that let ARM templates, VM deployments or disk encryption
  # read secrets without an RBAC grant. None are needed for app secrets.
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false

  # Always present, and written as plain values rather than a dynamic
  # block or an object lookup, so scanners evaluate the real result.
  # Allow only when the vault is public with no rules; Deny otherwise.
  network_acls {
    default_action             = var.public_network_access_enabled && length(var.firewall_ip_rules) == 0 && length(var.firewall_subnet_ids) == 0 ? "Allow" : "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.firewall_ip_rules
    virtual_network_subnet_ids = var.firewall_subnet_ids
  }

  lifecycle {
    precondition {
      condition     = var.public_network_access_enabled || (length(var.firewall_ip_rules) == 0 && length(var.firewall_subnet_ids) == 0)
      error_message = "Firewall rules filter public traffic, so they only make sense with public_network_access_enabled = true."
    }
  }
}

# Audit log: every secret get, set and delete, with the caller's identity.
resource "azurerm_monitor_diagnostic_setting" "workload" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_key_vault.workload.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
}

resource "azurerm_role_assignment" "workload" {
  for_each = var.role_assignments

  scope = azurerm_key_vault.workload.id

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
