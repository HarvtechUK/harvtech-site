# A single-container Container App with the house rules fixed in code:
#
# - Secrets are Key Vault references only. There is no input that takes
#   a secret value, so nothing secret can reach Terraform state.
# - HTTPS only. Plain HTTP is never accepted at the ingress.
# - A system-assigned managed identity, always, for keyless access to
#   the registry, Key Vault and data services.
# - Deployments own the running image; Terraform owns everything else.
#
# Ingress is internal unless made public deliberately, and HTTP health
# probes replace the platform's port-open TCP check when a path is given.

locals {
  # Plain and secret-backed variables, keyed by name. One map means one
  # stable ordering (by name), and a name cannot be defined twice.
  env_vars = merge(
    { for name, value in var.env : name => { value = value, secret_name = null } },
    { for name, secret in var.secret_env : name => { value = null, secret_name = secret } },
  )

  identity_type = length(var.user_assigned_identity_ids) == 0 ? "SystemAssigned" : "SystemAssigned, UserAssigned"
}

resource "azurerm_container_app" "workload" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = var.revision_mode
  tags                         = var.tags

  identity {
    type         = local.identity_type
    identity_ids = var.user_assigned_identity_ids
  }

  dynamic "registry" {
    for_each = var.registry == null ? [] : [var.registry]

    content {
      server   = registry.value.server
      identity = registry.value.identity
    }
  }

  dynamic "secret" {
    for_each = var.secrets

    content {
      name                = secret.key
      key_vault_secret_id = secret.value.key_vault_secret_id
      identity            = secret.value.identity
    }
  }

  ingress {
    external_enabled = var.external_ingress_enabled
    target_port      = var.target_port
    transport        = "auto"

    # Not configurable: plain HTTP is redirected, never served.
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.container_name
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = local.env_vars

        content {
          name        = env.key
          value       = env.value.value
          secret_name = env.value.secret_name
        }
      }

      dynamic "liveness_probe" {
        for_each = var.health_probe_path == null ? [] : [var.health_probe_path]

        content {
          transport = "HTTP"
          port      = var.target_port
          path      = liveness_probe.value
        }
      }

      dynamic "readiness_probe" {
        for_each = var.health_probe_path == null ? [] : [var.health_probe_path]

        content {
          transport = "HTTP"
          port      = var.target_port
          path      = readiness_probe.value
        }
      }
    }
  }

  lifecycle {
    # The deployment pipeline ships new images; Terraform would otherwise
    # roll every app back to var.image on the next apply.
    ignore_changes = [template[0].container[0].image]

    precondition {
      condition     = length(setintersection(keys(var.env), keys(var.secret_env))) == 0
      error_message = "A variable name appears in both env and secret_env. Each name must be defined once."
    }

    precondition {
      condition     = alltrue([for secret in values(var.secret_env) : contains(keys(var.secrets), secret)])
      error_message = "secret_env references a secret that is not defined in secrets."
    }

    precondition {
      condition     = var.min_replicas <= var.max_replicas
      error_message = "min_replicas cannot exceed max_replicas."
    }
  }
}
