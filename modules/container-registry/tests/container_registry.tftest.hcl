# Unit tests for modules/container-registry. The azurerm provider is
# mocked, so these run anywhere with no Azure credentials:
#
#   terraform -chdir=modules/container-registry init -backend=false
#   terraform -chdir=modules/container-registry test

mock_provider "azurerm" {
  # The provider still parses role assignment scopes, and the mock's
  # default random-string ID is not a valid Azure resource ID.
  mock_resource "azurerm_container_registry" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-harvtech-test-prd-uks-01/providers/Microsoft.ContainerRegistry/registries/crharvtechtestprduks01"
    }
  }
}

variables {
  name                = "crharvtechtestprduks01"
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

run "identities_only_no_shared_credentials" {
  command = plan

  assert {
    condition     = azurerm_container_registry.workload.admin_enabled == false
    error_message = "The admin user must be disabled."
  }

  assert {
    condition     = azurerm_container_registry.workload.anonymous_pull_enabled == false
    error_message = "Anonymous pulls must be disabled."
  }
}

run "defaults_to_premium_private_with_retention" {
  command = plan

  assert {
    condition     = azurerm_container_registry.workload.sku == "Premium" && azurerm_container_registry.workload.public_network_access_enabled == false
    error_message = "The default registry should be Premium and private."
  }

  assert {
    condition     = azurerm_container_registry.workload.retention_policy_in_days == 7
    error_message = "Premium registries should clear untagged manifests after 7 days by default."
  }
}

run "allows_a_deliberately_public_basic_registry" {
  command = plan

  variables {
    sku                           = "Basic"
    public_network_access_enabled = true
  }

  assert {
    condition     = azurerm_container_registry.workload.retention_policy_in_days == null
    error_message = "Retention is a Premium feature and must not be set on Basic."
  }
}

run "refuses_a_private_basic_registry" {
  command = plan

  variables {
    sku = "Basic"
  }

  expect_failures = [azurerm_container_registry.workload]
}

run "rejects_a_name_without_the_caf_prefix" {
  command = plan

  variables {
    name = "harvtechregistry"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_with_hyphens" {
  command = plan

  variables {
    name = "cr-harvtech-test"
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

run "rejects_an_unknown_sku" {
  command = plan

  variables {
    sku = "Free"
  }

  expect_failures = [var.sku]
}

run "grants_pull_to_an_app_identity" {
  command = apply

  variables {
    role_assignments = {
      app_pull = {
        role_definition_id_or_name = "AcrPull"
        principal_id               = "11111111-2222-3333-4444-555555555555"
        principal_type             = "ServicePrincipal"
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.workload["app_pull"].role_definition_name == "AcrPull"
    error_message = "A role name should be passed as role_definition_name."
  }

  assert {
    condition     = azurerm_role_assignment.workload["app_pull"].scope == azurerm_container_registry.workload.id
    error_message = "Role assignments should be scoped to the registry."
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
