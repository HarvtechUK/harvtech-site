# Unit tests for modules/storage-account. The azurerm provider is
# mocked, so these run anywhere with no Azure credentials and nothing is
# deployed:
#
#   terraform -chdir=modules/storage-account init -backend=false
#   terraform -chdir=modules/storage-account test

mock_provider "azurerm" {
  # The provider still parses ID arguments (container storage_account_id,
  # role assignment scope), and the mock's default random-string ID is
  # not a valid Azure resource ID.
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-harvtech-test-prd-uks-01/providers/Microsoft.Storage/storageAccounts/stharvtechtestprduks01"
    }
  }
}

variables {
  name                = "stharvtechtestprduks01"
  resource_group_name = "rg-harvtech-test-prd-uks-01"
  location            = "uksouth"
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
    condition     = azurerm_storage_account.workload.shared_access_key_enabled == false
    error_message = "Shared keys must be disabled."
  }

  assert {
    condition     = azurerm_storage_account.workload.default_to_oauth_authentication == true
    error_message = "Entra ID must be the default auth for data-plane calls."
  }

  assert {
    condition     = azurerm_storage_account.workload.min_tls_version == "TLS1_2" && azurerm_storage_account.workload.https_traffic_only_enabled
    error_message = "TLS 1.2 minimum and HTTPS only must be enforced."
  }

  assert {
    condition     = azurerm_storage_account.workload.allow_nested_items_to_be_public == false
    error_message = "Anonymous blob access must be disabled at the account."
  }

  assert {
    condition     = azurerm_storage_account.workload.local_user_enabled == false && azurerm_storage_account.workload.cross_tenant_replication_enabled == false
    error_message = "Local users and cross-tenant replication must be off."
  }

  assert {
    condition     = azurerm_storage_account.workload.infrastructure_encryption_enabled == true
    error_message = "Infrastructure (double) encryption must be on."
  }

  assert {
    condition     = azurerm_storage_account.workload.sas_policy[0].expiration_period == "00.01:00:00"
    error_message = "SAS lifetime must be capped at one hour."
  }

  assert {
    condition     = azurerm_storage_account.workload.blob_properties[0].delete_retention_policy[0].days == 7
    error_message = "Blob soft delete should default to 7 days."
  }
}

run "defaults_to_resilient_and_private" {
  command = plan

  assert {
    condition     = azurerm_storage_account.workload.account_replication_type == "ZRS"
    error_message = "Replication should default to ZRS."
  }

  assert {
    condition     = azurerm_storage_account.workload.public_network_access_enabled == false
    error_message = "Public network access should default to off."
  }

  assert {
    condition     = length(azurerm_storage_account_network_rules.workload) == 0
    error_message = "No firewall unless network_rules is set."
  }

  assert {
    condition     = length(azurerm_storage_account_static_website.workload) == 0 && length(azurerm_storage_container.workload) == 0 && length(azurerm_role_assignment.workload) == 0
    error_message = "Static website, containers and role assignments should all be off by default."
  }
}

# --- Guardrails --------------------------------------------------------

run "rejects_a_name_without_the_caf_prefix" {
  command = plan

  variables {
    name = "harvtechtest01"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_with_hyphens_or_capitals" {
  command = plan

  variables {
    name = "st-HarvTech-test"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_longer_than_24_characters" {
  command = plan

  variables {
    name = "stharvtechtestprduks01abc"
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

run "rejects_an_unknown_replication_type" {
  command = plan

  variables {
    replication_type = "PREMIUM"
  }

  expect_failures = [var.replication_type]
}

run "rejects_soft_delete_retention_out_of_range" {
  command = plan

  variables {
    blob_soft_delete_retention_days = 0
  }

  expect_failures = [var.blob_soft_delete_retention_days]
}

run "rejects_network_rules_on_a_private_account" {
  command = plan

  variables {
    network_rules = { ip_rules = ["203.0.113.10"] }
  }

  expect_failures = [var.network_rules]
}

# --- Optional features -------------------------------------------------

run "serves_a_static_website_through_the_standalone_resource" {
  command = apply

  variables {
    public_network_access_enabled = true
    static_website                = {}
  }

  assert {
    condition     = azurerm_storage_account_static_website.workload[0].index_document == "index.html" && azurerm_storage_account_static_website.workload[0].error_404_document == "404.html"
    error_message = "Static website documents should default to index.html and 404.html."
  }

  assert {
    condition     = azurerm_storage_account_static_website.workload[0].storage_account_id == azurerm_storage_account.workload.id
    error_message = "Static website should attach to this account."
  }
}

run "creates_a_data_lake_with_private_containers" {
  command = apply

  variables {
    hierarchical_namespace_enabled = true
    containers                     = ["raw", "cleansed", "curated"]
  }

  assert {
    condition     = azurerm_storage_account.workload.is_hns_enabled == true
    error_message = "hierarchical_namespace_enabled should turn on HNS (ADLS Gen2)."
  }

  assert {
    condition     = toset(keys(azurerm_storage_container.workload)) == toset(["raw", "cleansed", "curated"])
    error_message = "Containers should be keyed by name."
  }

  assert {
    condition     = alltrue([for container in azurerm_storage_container.workload : container.container_access_type == "private"])
    error_message = "Every container must be private."
  }

  assert {
    condition     = toset(keys(output.container_ids)) == toset(["raw", "cleansed", "curated"])
    error_message = "container_ids output should be keyed by container name."
  }
}

run "rejects_an_invalid_container_name" {
  command = plan

  variables {
    containers = ["Raw--Data"]
  }

  expect_failures = [var.containers]
}

run "adds_a_firewall_that_denies_by_default" {
  command = plan

  variables {
    public_network_access_enabled = true
    network_rules                 = { ip_rules = ["203.0.113.10"] }
  }

  assert {
    condition     = azurerm_storage_account_network_rules.workload[0].default_action == "Deny"
    error_message = "Network rules must deny by default."
  }

  assert {
    condition     = azurerm_storage_account_network_rules.workload[0].bypass == toset(["AzureServices"])
    error_message = "Trusted Azure services must always bypass the firewall."
  }

  assert {
    condition     = azurerm_storage_account_network_rules.workload[0].ip_rules == toset(["203.0.113.10"])
    error_message = "IP rules should pass through."
  }
}

run "grants_data_plane_access_by_role_name" {
  command = apply

  variables {
    role_assignments = {
      app_read = {
        role_definition_id_or_name = "Storage Blob Data Reader"
        principal_id               = "11111111-2222-3333-4444-555555555555"
        principal_type             = "ServicePrincipal"
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.workload["app_read"].role_definition_name == "Storage Blob Data Reader"
    error_message = "A role name should be passed as role_definition_name."
  }

  assert {
    condition     = azurerm_role_assignment.workload["app_read"].scope == azurerm_storage_account.workload.id
    error_message = "Role assignments should be scoped to the account."
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
