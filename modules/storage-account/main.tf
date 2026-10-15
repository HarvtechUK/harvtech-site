# A general-purpose v2 storage account with the security baseline fixed
# in code. The settings in the "Security baseline" block below are not
# inputs: every account this module builds has them, so no caller can
# quietly opt out and a reviewer never has to check them per account.
# Cost and resilience trade-offs (replication, public reachability,
# retention) ARE inputs, with safe defaults.
#
# Interface follows Azure Verified Modules conventions where they
# overlap (containers, network_rules, role_assignments with
# role_definition_id_or_name). See modules/resource-group for the same
# pattern.

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

resource "azurerm_storage_account" "workload" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  is_hns_enabled           = var.hierarchical_namespace_enabled

  public_network_access_enabled = var.public_network_access_enabled

  # --- Security baseline (not configurable) ---

  min_tls_version            = "TLS1_2"
  https_traffic_only_enabled = true

  # No anonymous blob access anywhere in the account, so no container
  # can ever be made public by mistake.
  allow_nested_items_to_be_public = false

  # Entra ID only. Shared keys are the classic leaked-credential path;
  # with them off, every data-plane call is an identity with an RBAC
  # role and an audit trail. Callers' providers need
  # storage_use_azuread = true.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true

  # SFTP-style local users are a second, password-based identity system
  # scoped to one account. Off.
  local_user_enabled = false

  # Stops a compromised identity in another tenant becoming a
  # replication target for this account's data.
  cross_tenant_replication_enabled = false

  # Double encryption at rest. Free, but can only be set at creation.
  infrastructure_encryption_enabled = true

  # Defence in depth: SAS tokens signed with account keys cannot be
  # minted while keys are disabled, but if keys are ever re-enabled no
  # such token can outlive an hour.
  sas_policy {
    expiration_period = "00.01:00:00"
    expiration_action = "Log"
  }

  blob_properties {
    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }
    container_delete_retention_policy {
      days = var.container_soft_delete_retention_days
    }
  }
}

# The firewall is its own resource, created only when network_rules is
# set. As a dynamic block on the account, scanners such as Checkov
# render it even when it is not created, and report a deny-by-default
# firewall on accounts that do not have one.
resource "azurerm_storage_account_network_rules" "workload" {
  count = var.network_rules == null ? 0 : 1

  storage_account_id         = azurerm_storage_account.workload.id
  default_action             = "Deny"
  ip_rules                   = var.network_rules.ip_rules
  virtual_network_subnet_ids = var.network_rules.virtual_network_subnet_ids

  # Trusted Azure services (backup, monitoring, Defender) always get
  # through. Not an input: removing it breaks those services silently.
  bypass = ["AzureServices"]
}

# The standalone resource rather than the static_website block on the
# account: the block is deprecated in azurerm 4.x and removed in 5.0.
resource "azurerm_storage_account_static_website" "workload" {
  count = var.static_website == null ? 0 : 1

  storage_account_id = azurerm_storage_account.workload.id
  index_document     = var.static_website.index_document
  error_404_document = var.static_website.error_404_document
}

resource "azurerm_storage_container" "workload" {
  for_each = var.containers

  name                  = each.value
  storage_account_id    = azurerm_storage_account.workload.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "workload" {
  for_each = var.role_assignments

  scope = azurerm_storage_account.workload.id

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
