# container-registry

A container registry that only identities can use. The admin user (one
shared username and password with push and pull rights) and anonymous
pulls are both **off, and not configurable**. Apps pull with their
managed identity (`AcrPull`) and CI pushes with its own (`AcrPush`),
granted through `role_assignments`.

The tier defaults to **Premium and private**, the only combination with
private access and untagged-manifest retention. A cheaper tier is a
visible choice at the call site, and the module refuses combinations
Azure would reject (a private Basic registry) at plan time rather than
mid-apply.

## Usage

```hcl
module "container_registry" {
  source              = "../modules/container-registry"
  name                = module.naming.container_registry
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = module.tags.tags

  # The portal's choice: one first-party image, so Basic and public.
  sku                           = "Basic"
  public_network_access_enabled = true

  role_assignments = {
    portal_pull = {
      role_definition_id_or_name = "AcrPull"
      principal_id               = azurerm_container_app.portal.identity[0].principal_id
      principal_type             = "ServicePrincipal"
    }
  }
}
```

## Security baseline (not configurable)

| Setting | Value | Why |
|---|---|---|
| `admin_enabled` | `false` | A shared credential with push rights is the classic registry compromise path. |
| `anonymous_pull_enabled` | `false` | Every pull is an identity with a role and an audit trail. |
| `retention_policy_in_days` | Premium: `untagged_retention_days` | Superseded layers don't accumulate (and don't keep old vulnerable images pullable by digest). Not available below Premium. |

## Trade-offs (inputs with safe defaults)

| Input | Default | Override when |
|---|---|---|
| `sku` | `Premium` | A small first-party registry doesn't justify ~£40/mo; `Basic` is ~£4. |
| `public_network_access_enabled` | `false` | The tier isn't Premium (it must then be `true`), or consumers can't reach it privately. |
| `untagged_retention_days` | `7` | Premium only. |

Plus the house guardrails: CAF `cr` prefix, UK regions only by default,
mandatory tag keys, and no standing Owner, User Access Administrator or
Role Based Access Control Administrator grants.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | `cr…`, 5-50 letters and digits. |
| `resource_group_name` | `string` | required | Normally `module.resource_group.name`. |
| `location` | `string` | required | Must be in `allowed_locations`. |
| `tags` | `map(string)` | required | Normally `module.tags.tags`. |
| `allowed_locations` | `list(string)` | `["uksouth", "ukwest"]` | Regions the module will deploy to. |
| `required_tag_keys` | `list(string)` | ownership and cost keys | Tag keys the registry must carry. |
| `sku` | `string` | `Premium` | `Basic`, `Standard` or `Premium`. |
| `public_network_access_enabled` | `bool` | `false` | Must be `true` below Premium. |
| `untagged_retention_days` | `number` | `7` | 1-365, Premium only. |
| `role_assignments` | `map(object)` | `{}` | Same shape as the other modules. |

## Outputs

| Name | Description |
|---|---|
| `id` | Registry ID, for role assignments. |
| `name` | For `az acr` calls. |
| `login_server` | `<name>.azurecr.io`, for image references and an app's registry block. |
| `role_assignment_ids` | Keyed like `role_assignments`. |

## Testing

```bash
terraform -chdir=modules/container-registry init -backend=false
terraform -chdir=modules/container-registry test
```

11 runs against a mocked azurerm provider.
