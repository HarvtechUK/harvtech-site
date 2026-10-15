# Unit tests for modules/resource-group. The azurerm provider is mocked,
# so these run anywhere (laptop or CI) with no Azure credentials and
# nothing is deployed:
#
#   terraform -chdir=modules/resource-group init -backend=false
#   terraform -chdir=modules/resource-group test

mock_provider "azurerm" {
  # The provider still parses scope arguments, and the mock's default
  # random-string ID is not a valid Azure resource ID.
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-harvtech-test-prd-uks-01"
    }
  }
}

variables {
  name     = "rg-harvtech-test-prd-uks-01"
  location = "uksouth"
  tags = {
    project     = "harvtech"
    workload    = "test"
    environment = "prd"
    owner       = "alex@harvtech.co.uk"
    cost_centre = "personal"
    managed_by  = "terraform"
  }
}

# --- Defaults ---------------------------------------------------------

run "creates_only_the_resource_group_by_default" {
  command = plan

  assert {
    condition     = azurerm_resource_group.workload.name == "rg-harvtech-test-prd-uks-01"
    error_message = "Resource group name should pass through unchanged."
  }

  assert {
    condition     = azurerm_resource_group.workload.tags["owner"] == "alex@harvtech.co.uk"
    error_message = "Tags should pass through unchanged."
  }

  assert {
    condition     = length(azurerm_management_lock.workload) == 0
    error_message = "No lock should be created unless one is requested."
  }

  assert {
    condition     = length(azurerm_role_assignment.workload) == 0
    error_message = "No role assignments should be created by default."
  }
}

# --- Location guardrail -----------------------------------------------

run "accepts_display_name_form_of_a_uk_region" {
  command = plan

  variables {
    location = "UK West"
  }
}

run "rejects_a_region_outside_the_uk_by_default" {
  command = plan

  variables {
    location = "eastus"
  }

  expect_failures = [var.location]
}

run "allows_a_deliberately_widened_region_list" {
  command = plan

  variables {
    location          = "westeurope"
    allowed_locations = ["uksouth", "westeurope"]
  }
}

# --- Naming guardrail -------------------------------------------------

run "rejects_a_name_without_the_caf_prefix" {
  command = plan

  variables {
    name = "harvtech-test"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_ending_in_a_period" {
  command = plan

  variables {
    name = "rg-harvtech-test."
  }

  expect_failures = [var.name]
}

run "rejects_a_name_longer_than_90_characters" {
  command = plan

  variables {
    name = "rg-${join("", [for i in range(30) : "abc"])}"
  }

  expect_failures = [var.name]
}

# --- Tag guardrail ----------------------------------------------------

run "rejects_tags_missing_a_required_key" {
  command = plan

  variables {
    tags = {
      project     = "harvtech"
      workload    = "test"
      environment = "prd"
    }
  }

  expect_failures = [var.tags]
}

# --- Management lock --------------------------------------------------

run "creates_a_named_lock_when_requested" {
  command = apply

  variables {
    lock = { kind = "CanNotDelete" }
  }

  assert {
    condition     = azurerm_management_lock.workload[0].lock_level == "CanNotDelete"
    error_message = "Lock level should match lock.kind."
  }

  assert {
    condition     = azurerm_management_lock.workload[0].name == "lock-rg-harvtech-test-prd-uks-01"
    error_message = "Lock name should default to lock-<resource group name>."
  }

  assert {
    condition     = azurerm_management_lock.workload[0].scope == azurerm_resource_group.workload.id
    error_message = "Lock should be scoped to the resource group."
  }

  assert {
    condition     = output.lock_id == azurerm_management_lock.workload[0].id
    error_message = "lock_id output should expose the lock."
  }
}

run "rejects_an_unknown_lock_kind" {
  command = plan

  variables {
    lock = { kind = "DoNotTouch" }
  }

  expect_failures = [var.lock]
}

# --- Role assignments -------------------------------------------------

run "assigns_a_role_by_name" {
  command = apply

  variables {
    role_assignments = {
      auditors_read = {
        role_definition_id_or_name = "Reader"
        principal_id               = "11111111-2222-3333-4444-555555555555"
        principal_type             = "Group"
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.workload["auditors_read"].role_definition_name == "Reader"
    error_message = "A role name should be passed as role_definition_name."
  }

  assert {
    condition     = azurerm_role_assignment.workload["auditors_read"].scope == azurerm_resource_group.workload.id
    error_message = "Role assignments should be scoped to the resource group."
  }

  assert {
    condition     = keys(output.role_assignment_ids) == ["auditors_read"]
    error_message = "role_assignment_ids should be keyed like var.role_assignments."
  }
}

run "assigns_a_role_by_definition_id" {
  command = plan

  variables {
    role_assignments = {
      auditors_read = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "11111111-2222-3333-4444-555555555555"
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.workload["auditors_read"].role_definition_id == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "A full role definition ID should be passed as role_definition_id."
  }
}

run "refuses_standing_owner_by_name" {
  command = plan

  variables {
    role_assignments = {
      break_things = {
        role_definition_id_or_name = "owner"
        principal_id               = "11111111-2222-3333-4444-555555555555"
      }
    }
  }

  expect_failures = [var.role_assignments]
}

run "refuses_standing_user_access_administrator_by_definition_id" {
  command = plan

  variables {
    role_assignments = {
      escalate = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"
        principal_id               = "11111111-2222-3333-4444-555555555555"
      }
    }
  }

  expect_failures = [var.role_assignments]
}

run "rejects_a_upn_as_principal_id" {
  command = plan

  variables {
    role_assignments = {
      auditors_read = {
        role_definition_id_or_name = "Reader"
        principal_id               = "auditor@example.com"
      }
    }
  }

  expect_failures = [var.role_assignments]
}
