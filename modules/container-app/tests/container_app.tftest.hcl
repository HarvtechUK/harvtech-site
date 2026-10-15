# Unit tests for modules/container-app. The azurerm provider is mocked,
# so these run anywhere with no Azure credentials:
#
#   terraform -chdir=modules/container-app init -backend=false
#   terraform -chdir=modules/container-app test

mock_provider "azurerm" {}

variables {
  name                         = "ca-harvtech-test-prd-uks-01"
  resource_group_name          = "rg-harvtech-test-prd-uks-01"
  container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-harvtech-test-prd-uks-01/providers/Microsoft.App/managedEnvironments/cae-harvtech-test-prd-uks-01"
  image                        = "mcr.microsoft.com/k8se/quickstart:latest"
  target_port                  = 8000
  tags = {
    project     = "harvtech"
    workload    = "test"
    environment = "prd"
    owner       = "alex@harvtech.co.uk"
    cost_centre = "personal"
    managed_by  = "terraform"
  }
}

# --- Baseline ----------------------------------------------------------

run "applies_the_baseline" {
  command = plan

  assert {
    condition     = azurerm_container_app.workload.ingress[0].allow_insecure_connections == false
    error_message = "Plain HTTP must never be served."
  }

  assert {
    condition     = azurerm_container_app.workload.identity[0].type == "SystemAssigned"
    error_message = "Every app gets a system-assigned identity."
  }

  assert {
    condition     = azurerm_container_app.workload.ingress[0].external_enabled == false
    error_message = "Ingress should be internal unless made public deliberately."
  }

  assert {
    condition     = length(azurerm_container_app.workload.secret) == 0 && length(azurerm_container_app.workload.registry) == 0
    error_message = "No secrets or registry unless configured."
  }

  assert {
    condition     = length(azurerm_container_app.workload.template[0].container[0].liveness_probe) == 0
    error_message = "No HTTP probes unless a health path is given."
  }
}

# --- Secrets: references only ------------------------------------------

run "wires_key_vault_references_into_env" {
  command = plan

  variables {
    env = {
      COSMOS_DATABASE = "portal"
    }
    secrets = {
      session-secret = { key_vault_secret_id = "https://kvharvtechtest.vault.azure.net/secrets/session-secret" }
    }
    secret_env = {
      SESSION_SECRET = "session-secret"
    }
  }

  assert {
    condition     = one([for s in azurerm_container_app.workload.secret : s if s.name == "session-secret"]).identity == "System"
    error_message = "Secrets should be read with the system identity by default."
  }

  assert {
    condition     = one([for s in azurerm_container_app.workload.secret : s if s.name == "session-secret"]).key_vault_secret_id == "https://kvharvtechtest.vault.azure.net/secrets/session-secret"
    error_message = "The Key Vault reference should pass through."
  }

  assert {
    condition     = one([for s in azurerm_container_app.workload.secret : s if s.name == "session-secret"]).value == null
    error_message = "No secret value may ever be set."
  }

  assert {
    condition     = [for e in azurerm_container_app.workload.template[0].container[0].env : e.name] == ["COSMOS_DATABASE", "SESSION_SECRET"]
    error_message = "Env vars should be ordered by name, plain and secret-backed together."
  }

  assert {
    condition     = one([for e in azurerm_container_app.workload.template[0].container[0].env : e.secret_name if e.name == "SESSION_SECRET"]) == "session-secret"
    error_message = "A secret-backed variable should reference the secret by name."
  }
}

run "rejects_a_versioned_secret_reference" {
  command = plan

  variables {
    secrets = {
      session-secret = { key_vault_secret_id = "https://kvharvtechtest.vault.azure.net/secrets/session-secret/0123456789abcdef0123456789abcdef" }
    }
  }

  expect_failures = [var.secrets]
}

run "rejects_a_secret_that_is_not_a_key_vault_reference" {
  command = plan

  variables {
    secrets = {
      session-secret = { key_vault_secret_id = "correct-horse-battery-staple" }
    }
  }

  expect_failures = [var.secrets]
}

run "rejects_secret_env_pointing_at_an_undefined_secret" {
  command = plan

  variables {
    secret_env = {
      SESSION_SECRET = "session-secret"
    }
  }

  expect_failures = [azurerm_container_app.workload]
}

run "rejects_a_variable_defined_twice" {
  command = plan

  variables {
    env = {
      SESSION_SECRET = "oops"
    }
    secrets = {
      session-secret = { key_vault_secret_id = "https://kvharvtechtest.vault.azure.net/secrets/session-secret" }
    }
    secret_env = {
      SESSION_SECRET = "session-secret"
    }
  }

  expect_failures = [azurerm_container_app.workload]
}

# --- Optional features -------------------------------------------------

run "public_app_with_registry_and_health_probes" {
  command = plan

  variables {
    external_ingress_enabled = true
    health_probe_path        = "/healthz"
    registry                 = { server = "crharvtechtest.azurecr.io" }
  }

  assert {
    condition     = azurerm_container_app.workload.ingress[0].external_enabled == true
    error_message = "external_ingress_enabled should make the app public."
  }

  assert {
    condition     = azurerm_container_app.workload.registry[0].server == "crharvtechtest.azurecr.io" && azurerm_container_app.workload.registry[0].identity == "system"
    error_message = "The registry should be pulled with the system identity."
  }

  assert {
    condition = (
      azurerm_container_app.workload.template[0].container[0].liveness_probe[0].path == "/healthz" &&
      azurerm_container_app.workload.template[0].container[0].readiness_probe[0].path == "/healthz" &&
      azurerm_container_app.workload.template[0].container[0].readiness_probe[0].port == 8000
    )
    error_message = "HTTP probes should hit the health path on the target port."
  }

  assert {
    condition     = azurerm_container_app.workload.template[0].container[0].readiness_probe[0].success_count_threshold == 1
    error_message = "Readiness should need one success, so scale-from-zero isn't delayed ~30s."
  }
}

run "adds_user_assigned_identities_alongside_the_system_one" {
  command = plan

  variables {
    user_assigned_identity_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-app"]
  }

  assert {
    condition     = azurerm_container_app.workload.identity[0].type == "SystemAssigned, UserAssigned"
    error_message = "User-assigned identities should be added, not substituted."
  }
}

# --- Guardrails --------------------------------------------------------

run "rejects_a_name_without_the_caf_prefix" {
  command = plan

  variables {
    name = "portal-app"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_longer_than_32_characters" {
  command = plan

  variables {
    name = "ca-harvtech-portal-prd-uks-01-extra"
  }

  expect_failures = [var.name]
}

run "rejects_tags_missing_a_required_key" {
  command = plan

  variables {
    tags = { project = "harvtech" }
  }

  expect_failures = [var.tags]
}

run "rejects_cpu_off_the_quarter_step" {
  command = plan

  variables {
    cpu = 0.3
  }

  expect_failures = [var.cpu]
}

run "rejects_min_replicas_above_max" {
  command = plan

  variables {
    min_replicas = 3
    max_replicas = 2
  }

  expect_failures = [azurerm_container_app.workload]
}
