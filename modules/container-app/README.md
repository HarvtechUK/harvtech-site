# container-app

A single-container Container App where **secrets can only be Key Vault
references**. There is no input that takes a secret value, so no secret
can reach Terraform state through this module, by design or by accident.

That matters because of how the azurerm provider works: it reads a
Container App's secret values back from Azure on every refresh and
stores them in state, even with `ignore_changes`. A Key Vault reference
has no value to read back, so the state holds only a URL.

## Usage

```hcl
module "container_app" {
  source                       = "../modules/container-app"
  name                         = module.naming.container_app
  resource_group_name          = module.resource_group.name
  container_app_environment_id = module.container_app_environment.id
  tags                         = module.tags.tags

  image                    = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" # first deploy only
  target_port              = 8000
  external_ingress_enabled = true
  health_probe_path        = "/healthz"

  registry = { server = module.container_registry.login_server }

  env = {
    COSMOS_ENDPOINT = azurerm_cosmosdb_account.app.endpoint
  }

  secrets = {
    session-secret = { key_vault_secret_id = "${module.key_vault.vault_uri}secrets/session-secret" }
  }

  secret_env = {
    SESSION_SECRET = "session-secret"
  }
}
```

The app's identity then needs `AcrPull` on the registry and `Key Vault
Secrets User` on the vault, through those modules' `role_assignments`
and `module.container_app.principal_id`.

## Opinions (not configurable)

| Rule | Why |
|---|---|
| **Secrets are Key Vault references, versionless only** | No value ever enters state. Versionless (`…/secrets/<name>`, no version segment) means a rotated value is picked up without a code change; a pinned version is refused. |
| **HTTPS only** (`allow_insecure_connections = false`) | Plain HTTP is redirected, never served. |
| **System-assigned identity, always** | Keyless access to the registry, Key Vault and data services. User-assigned identities are added alongside, never instead. |
| **Deployments own the image** (`ignore_changes`) | The pipeline ships images; Terraform owns everything else. Without this, every apply would roll the app back to the bootstrap image. |
| **Env and secret_env can't collide, and secret_env must name a defined secret** | Caught at plan time instead of as a broken revision. |

## Defaults on the safe side

| Input | Default | Why |
|---|---|---|
| `external_ingress_enabled` | `false` | Reachable only from inside the environment until made public deliberately. |
| `health_probe_path` | `null` (TCP) | Set it. The default TCP probe only proves a port is open; an HTTP probe proves the app answers. |
| `min_replicas` / `max_replicas` | `0` / `1` | Scale to zero; raise the ceiling deliberately. |

## Rotating a secret

Set the new value in Key Vault (see the runbook in
`modules/key-vault/README.md`). Because references are versionless, the
next revision reads the new value; Container Apps also refreshes
references periodically. No Terraform change is involved.

## First deployment of a new app

A **system-assigned** identity only exists once the app does, so it
can't be granted `AcrPull` or `Key Vault Secrets User` before the app's
first revision tries to pull an image or read a secret. Two ways round
it:

- Create a **user-assigned identity** first, grant it access, attach it
  with `user_assigned_identity_ids`, and point `registry.identity` and
  each secret's `identity` at its resource ID.
- Or bootstrap in two applies: first with a public image and no secrets,
  then add the registry and secrets once the grants exist.

The portal used the second route when it was created.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | `ca-…`, at most 32 lowercase letters, digits and single hyphens. |
| `resource_group_name` | `string` | required | Normally `module.resource_group.name`. |
| `container_app_environment_id` | `string` | required | Normally `module.container_app_environment.id`. |
| `tags` | `map(string)` | required | Normally `module.tags.tags`. |
| `image` | `string` | required | First deployment only. |
| `target_port` | `number` | required | Container listen port. |
| `container_name` | `string` | `app` | |
| `cpu` / `memory` | `number` / `string` | `0.25` / `0.5Gi` | Consumption plan pairs. |
| `min_replicas` / `max_replicas` | `number` | `0` / `1` | |
| `revision_mode` | `string` | `Single` | `Multiple` for blue/green. |
| `health_probe_path` | `string` | `null` | HTTP liveness and readiness path. |
| `external_ingress_enabled` | `bool` | `false` | Public ingress. |
| `env` | `map(string)` | `{}` | Plain variables. Never secrets. |
| `secrets` | `map(object)` | `{}` | `{ key_vault_secret_id, identity? }`, versionless. `identity` defaults to `"System"`. |
| `secret_env` | `map(string)` | `{}` | `{ ENV_NAME = "secret-name" }`. |
| `registry` | `object` | `null` | `{ server, identity? }`. `identity` defaults to `"system"` (lowercase is how Azure stores it). |
| `user_assigned_identity_ids` | `list(string)` | `[]` | Extra identities. |
| `required_tag_keys` | `list(string)` | ownership and cost keys | |

## Outputs

| Name | Description |
|---|---|
| `id` | App ID. |
| `name` | For `az containerapp` calls. |
| `fqdn` | Ingress hostname. |
| `principal_id` | System identity, for role assignments. |
| `latest_revision_name` | For deployment checks. |
| `outbound_ip_addresses` | For allow-listing downstream. |

## Testing

```bash
terraform -chdir=modules/container-app init -backend=false
terraform -chdir=modules/container-app test
```

13 runs against a mocked azurerm provider. Mutation-checked: allowing
plain HTTP, slipping a secret **value** in instead of a reference,
probing the wrong path, or replacing the system identity each fails the
run that guards it.
