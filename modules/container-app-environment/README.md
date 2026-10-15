# container-app-environment

A Container Apps environment: the shared boundary (networking and
logging) that one or more container apps run inside.

The opinion that isn't negotiable is **logging**: `log_analytics_workspace_id`
is required, so every app's stdout/stderr and the platform's system logs
always land somewhere you can query. An environment whose logs go
nowhere can't be investigated.

## Usage

```hcl
module "container_app_environment" {
  source                     = "../modules/container-app-environment"
  name                       = module.naming.container_app_environment
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  tags                       = module.tags.tags
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id
}
```

## Networking: the trade-off to understand

Without `infrastructure_subnet_id`, the environment runs on
Microsoft-managed networking. That is simple and cheap, but its apps can
only reach **public** endpoints, so everything they depend on (Key Vault,
Cosmos DB, a registry) must accept public traffic, protected by Entra
RBAC rather than by the network. That is what the portal does today, and
why several private-networking findings are suppressed across its stack.

With a subnet (a dedicated /23 or larger on the Consumption plan), the
environment joins your VNet: dependencies can sit behind private
endpoints, and `internal_load_balancer_enabled = true` takes the apps off
the internet entirely. The module refuses an internal environment
without a subnet at plan time.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | `cae-…`, lowercase letters, digits and single hyphens. |
| `resource_group_name` | `string` | required | Normally `module.resource_group.name`. |
| `location` | `string` | required | Must be in `allowed_locations`. |
| `tags` | `map(string)` | required | Normally `module.tags.tags`. |
| `log_analytics_workspace_id` | `string` | required | Receives all app and system logs. |
| `allowed_locations` | `list(string)` | `["uksouth", "ukwest"]` | Regions the module will deploy to. |
| `required_tag_keys` | `list(string)` | ownership and cost keys | Tag keys the environment must carry. |
| `infrastructure_subnet_id` | `string` | `null` | VNet integration. |
| `internal_load_balancer_enabled` | `bool` | `false` | Private IP only; needs a subnet. |

## Outputs

| Name | Description |
|---|---|
| `id` | For an app's `container_app_environment_id`. |
| `name` | Environment name. |
| `default_domain` | An app's hostname is `<app name>.<default_domain>`, known before the app exists, so callers can build redirect URIs without a dependency cycle. |
| `static_ip_address` | Inbound IP with VNet integration; shared public IP without. |

## Testing

```bash
terraform -chdir=modules/container-app-environment init -backend=false
terraform -chdir=modules/container-app-environment test
```

8 runs against a mocked azurerm provider.
