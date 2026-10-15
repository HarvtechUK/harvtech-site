# Unit tests for modules/key-vault. The azurerm provider is mocked, so
# these run anywhere with no Azure credentials and nothing is deployed:
#
#   terraform -chdir=modules/key-vault init -backend=false
#   terraform -chdir=modules/key-vault test

mock_provider "azurerm" {
  # The provider still parses ID arguments (diagnostic setting target,
  # role assignment scope), and the mock's default random-string ID is
  # not a valid Azure resource ID.
  mock_resource "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-harvtech-test-prd-uks-01/providers/Microsoft.KeyVault/vaults/kvharvtechtestprduks01"
    }
  }
}

variables {
  name                       = "kvharvtechtestprduks01"
  resource_group_name        = "rg-harvtech-test-prd-uks-01"
  location                   = "uksouth"
  tenant_id                  = "00000000-0000-0000-0000-000000000000"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-harvtech-test-prd-uks-01/providers/Microsoft.OperationalInsights/workspaces/log-harvtech-test-prd-uks-01"
  tags = {
    project     = "harvtech"
    workload    = "test"
    environment = "prd"
    owner       = "alex@harvtech.co.uk"
    cost_centre = "personal"
    managed_by  = "terraform"
  }
}

# --- Security baseline -------------------------------------------------

run "applies_the_security_baseline" {
  command = plan

  assert {
    condition     = azurerm_key_vault.workload.rbac_authorization_enabled == true
    error_message = "The vault must use Azure RBAC, not access policies."
  }

  assert {
    condition     = azurerm_key_vault.workload.purge_protection_enabled == true && azurerm_key_vault.workload.soft_delete_retention_days == 90
    error_message = "Purge protection must be on with a 90-day soft-delete window."
  }

  assert {
    condition = (
      azurerm_key_vault.workload.enabled_for_deployment == false &&
      azurerm_key_vault.workload.enabled_for_disk_encryption == false &&
      azurerm_key_vault.workload.enabled_for_template_deployment == false
    )
    error_message = "ARM, VM and disk-encryption side doors must be closed."
  }
}

run "always_writes_an_audit_log" {
  command = apply

  assert {
    condition     = azurerm_monitor_diagnostic_setting.workload.target_resource_id == azurerm_key_vault.workload.id
    error_message = "The diagnostic setting must target the vault."
  }

  assert {
    condition     = one(azurerm_monitor_diagnostic_setting.workload.enabled_log[*].category_group) == "audit"
    error_message = "The audit log category group must be enabled."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.workload.log_analytics_workspace_id == var.log_analytics_workspace_id
    error_message = "Audit logs must go to the given workspace."
  }
}

run "defaults_to_private_and_denies" {
  command = plan

  assert {
    condition     = azurerm_key_vault.workload.public_network_access_enabled == false
    error_message = "Public network access should default to off."
  }

  assert {
    condition     = azurerm_key_vault.workload.network_acls[0].default_action == "Deny"
    error_message = "A private vault should record a Deny default action."
  }
}

run "records_allow_honestly_when_public_without_rules" {
  command = plan

  variables {
    public_network_access_enabled = true
  }

  assert {
    condition     = azurerm_key_vault.workload.network_acls[0].default_action == "Allow"
    error_message = "A public vault with no firewall rules must record Allow, not a misleading Deny."
  }
}

run "denies_by_default_when_a_firewall_is_set" {
  command = plan

  variables {
    public_network_access_enabled = true
    firewall_ip_rules             = ["203.0.113.10"]
  }

  assert {
    condition     = azurerm_key_vault.workload.network_acls[0].default_action == "Deny"
    error_message = "A configured firewall must deny by default."
  }

  assert {
    condition     = azurerm_key_vault.workload.network_acls[0].bypass == "AzureServices"
    error_message = "Trusted Azure services must bypass the firewall."
  }

  assert {
    condition     = azurerm_key_vault.workload.network_acls[0].ip_rules == toset(["203.0.113.10"])
    error_message = "IP rules should pass through."
  }
}

# --- Guardrails --------------------------------------------------------

run "rejects_a_name_without_the_caf_prefix" {
  command = plan

  variables {
    name = "vault-harvtech-test"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_longer_than_24_characters" {
  command = plan

  variables {
    name = "kvharvtechtestprduks01abc"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_with_consecutive_hyphens" {
  command = plan

  variables {
    name = "kv-harvtech--test"
  }

  expect_failures = [var.name]
}

run "rejects_a_region_outside_the_uk_by_default" {
  command = plan

  variables {
    location = "eastus"
  }

  expect_failures = [var.location]
}

run "rejects_tags_missing_a_required_key" {
  command = plan

  variables {
    tags = { project = "harvtech" }
  }

  expect_failures = [var.tags]
}

run "rejects_firewall_rules_on_a_private_vault" {
  command = plan

  variables {
    firewall_ip_rules = ["203.0.113.10"]
  }

  expect_failures = [azurerm_key_vault.workload]
}

run "rejects_a_malformed_firewall_ip_rule" {
  command = plan

  variables {
    public_network_access_enabled = true
    firewall_ip_rules             = ["not-an-ip"]
  }

  expect_failures = [var.firewall_ip_rules]
}

run "rejects_an_unknown_sku" {
  command = plan

  variables {
    sku_name = "basic"
  }

  expect_failures = [var.sku_name]
}

# --- Role assignments -------------------------------------------------

run "grants_secret_read_by_role_name" {
  command = apply

  variables {
    role_assignments = {
      app_secrets_read = {
        role_definition_id_or_name = "Key Vault Secrets User"
        principal_id               = "11111111-2222-3333-4444-555555555555"
        principal_type             = "ServicePrincipal"
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.workload["app_secrets_read"].role_definition_name == "Key Vault Secrets User"
    error_message = "A role name should be passed as role_definition_name."
  }

  assert {
    condition     = azurerm_role_assignment.workload["app_secrets_read"].scope == azurerm_key_vault.workload.id
    error_message = "Role assignments should be scoped to the vault."
  }
}

run "refuses_standing_owner" {
  command = plan

  variables {
    role_assignments = {
      break_glass = {
        role_definition_id_or_name = "Owner"
        principal_id               = "11111111-2222-3333-4444-555555555555"
      }
    }
  }

  expect_failures = [var.role_assignments]
}
