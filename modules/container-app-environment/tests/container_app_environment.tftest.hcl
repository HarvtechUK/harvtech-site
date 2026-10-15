# Unit tests for modules/container-app-environment. The azurerm provider
# is mocked, so these run anywhere with no Azure credentials:
#
#   terraform -chdir=modules/container-app-environment init -backend=false
#   terraform -chdir=modules/container-app-environment test

mock_provider "azurerm" {}

variables {
  name                       = "cae-harvtech-test-prd-uks-01"
  resource_group_name        = "rg-harvtech-test-prd-uks-01"
  location                   = "uksouth"
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

run "always_sends_logs_to_log_analytics" {
  command = plan

  assert {
    condition     = azurerm_container_app_environment.workload.log_analytics_workspace_id == var.log_analytics_workspace_id
    error_message = "Logs must go to the given workspace."
  }
}

run "defaults_to_managed_networking" {
  command = plan

  assert {
    condition     = azurerm_container_app_environment.workload.infrastructure_subnet_id == null
    error_message = "With no subnet, the environment should use managed networking."
  }
}

run "integrates_with_a_vnet_and_goes_internal" {
  command = plan

  variables {
    infrastructure_subnet_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-cae"
    internal_load_balancer_enabled = true
  }

  assert {
    condition     = azurerm_container_app_environment.workload.internal_load_balancer_enabled == true
    error_message = "An internal load balancer should be allowed with a subnet."
  }
}

run "refuses_an_internal_environment_without_a_subnet" {
  command = plan

  variables {
    internal_load_balancer_enabled = true
  }

  expect_failures = [azurerm_container_app_environment.workload]
}

run "rejects_a_name_without_the_caf_prefix" {
  command = plan

  variables {
    name = "env-harvtech-test"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_with_capitals" {
  command = plan

  variables {
    name = "cae-HarvTech-test"
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
