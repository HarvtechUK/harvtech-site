# storage-account

A general-purpose v2 storage account where the security baseline is
**fixed in code, not offered as options**. Every account this module
builds is Entra ID-only, TLS 1.2+, double-encrypted, soft-delete
protected and closed to anonymous access. A caller cannot opt out, so a
reviewer never has to re-check those settings account by account.

What callers *do* choose are the trade-offs: redundancy, whether the
account is reachable from public networks, and retention. Those default
to the safe side, so a cheaper or more open choice shows up as an
explicit line at the call site.

Interface conventions follow [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
where they overlap; see [docs/decisions/own-modules-avm-shaped](../../site/src/content/docs/decisions/own-modules-avm-shaped.md).

## Usage

A private, zone-redundant account (all defaults):

```hcl
module "app_storage" {
  source              = "../modules/storage-account"
  name                = module.naming.storage_account
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = module.tags.tags

  containers = ["uploads", "exports"]

  role_assignments = {
    api_read_write = {
      role_definition_id_or_name = "Storage Blob Data Contributor"
      principal_id               = azurerm_container_app.api.identity[0].principal_id
      principal_type             = "ServicePrincipal"
    }
  }
}
```

The two shapes this repo runs (see `infra/main.tf` and
`data-platform/main.tf`):

```hcl
# Static website behind Front Door Standard
module "site_storage" {
  # ...
  replication_type              = "LRS" # rebuilt from git on every deploy
  public_network_access_enabled = true  # Front Door Standard can't reach it privately
  static_website                = { index_document = "index.html", error_404_document = "404.html" }
}

# ADLS Gen2 data lake with medallion containers
module "datalake" {
  # ...
  hierarchical_namespace_enabled = true
  containers                     = ["raw", "cleansed", "curated"]
}
```

## Security baseline (not configurable)

| Setting | Value | Why |
|---|---|---|
| `shared_access_key_enabled` | `false` | Account keys are the classic leaked-credential path. Every data-plane call is an Entra identity with an RBAC role and an audit trail. |
| `default_to_oauth_authentication` | `true` | Portal and SDK clients default to Entra ID instead of trying keys first. |
| `allow_nested_items_to_be_public` | `false` | No container can be made anonymous, by mistake or otherwise. |
| `min_tls_version` / `https_traffic_only_enabled` | `TLS1_2` / `true` | No downgraded or plaintext transport. |
| `local_user_enabled` | `false` | Local users are a second, password-based identity system scoped to one account. |
| `cross_tenant_replication_enabled` | `false` | Data cannot be object-replicated into another tenant. |
| `infrastructure_encryption_enabled` | `true` | Double encryption at rest. Free, but only settable at creation. |
| `sas_policy` | 1 hour, `Log` | Defence in depth if keys are ever re-enabled. |
| Blob and container soft delete | on (7 days by default) | An accidental delete or overwrite is recoverable. |

Because keys are off, the **calling provider needs
`storage_use_azuread = true`** and the deploying identity needs a
data-plane role (for example Storage Blob Data Contributor) for
Terraform to read blob service properties.

## Trade-offs (inputs with safe defaults)

| Input | Default | Override when |
|---|---|---|
| `replication_type` | `ZRS` | `LRS` when the data is rebuildable from source; `GZRS` for regional failover. |
| `public_network_access_enabled` | `false` | The consumer cannot reach the account privately (for example Front Door Standard). Pair with `network_rules` where you can. |
| `network_rules` | none | Public access must be on. Sets default action **Deny**, with `ip_rules` and subnets as the exceptions and Azure services bypassing. |
| `blob_soft_delete_retention_days` / `container_soft_delete_retention_days` | `7` | Regulated data with longer recovery requirements (1-365). |

Plus the house guardrails shared with `modules/resource-group`: CAF
`st` name prefix, UK regions only by default (`allowed_locations`),
mandatory tag keys, and no standing Owner, User Access Administrator or
Role Based Access Control Administrator grants in `role_assignments`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | `st…`, 3-24 lowercase letters and digits. |
| `resource_group_name` | `string` | required | Normally `module.resource_group.name`. |
| `location` | `string` | required | Must be in `allowed_locations`. |
| `tags` | `map(string)` | required | Normally `module.tags.tags`. |
| `allowed_locations` | `list(string)` | `["uksouth", "ukwest"]` | Regions the module will deploy to. |
| `required_tag_keys` | `list(string)` | ownership and cost keys | Tag keys the account must carry. |
| `replication_type` | `string` | `ZRS` | `LRS`, `ZRS`, `GRS`, `GZRS`, `RAGRS` or `RAGZRS`. |
| `public_network_access_enabled` | `bool` | `false` | See trade-offs. |
| `network_rules` | `object` | `null` | `{ ip_rules?, virtual_network_subnet_ids?, bypass? }`. |
| `hierarchical_namespace_enabled` | `bool` | `false` | ADLS Gen2. Creation-time only. |
| `blob_soft_delete_retention_days` | `number` | `7` | 1-365. |
| `container_soft_delete_retention_days` | `number` | `7` | 1-365. |
| `static_website` | `object` | `null` | `{ index_document?, error_404_document? }`. |
| `containers` | `set(string)` | `[]` | Private containers to create. |
| `role_assignments` | `map(object)` | `{}` | Same shape as `modules/resource-group`. |

## Outputs

| Name | Description |
|---|---|
| `id` | Account ID, for role assignments and diagnostic settings. |
| `name` | For CLI and SDK calls. |
| `primary_blob_endpoint` | Blob service endpoint. |
| `primary_dfs_endpoint` | Data Lake (dfs) endpoint. |
| `primary_web_endpoint` / `primary_web_host` | Static website URL / hostname; `null` without `static_website`. |
| `container_ids` | Keyed by container name. |
| `role_assignment_ids` | Keyed like `role_assignments`. |

## azurerm 5.0 ready

The static website uses the standalone
`azurerm_storage_account_static_website` resource, not the
`static_website` block on the account, which is deprecated in 4.x and
removed in 5.0. `infra/moves.tf` shows how the live site was switched
over with an `import` block, adopting the existing website config
rather than recreating it.

## Testing

```bash
terraform -chdir=modules/storage-account init -backend=false
terraform -chdir=modules/storage-account test
```

16 runs against a mocked azurerm provider (no Azure credentials): the
baseline, the safe defaults, every guardrail rejecting bad input, and
each optional feature. The suite was mutation-checked: re-enabling
shared keys, flipping the firewall to Allow, or making a container
public each fails the run that guards it.

## Adoption

Adopted by two live stacks with `moved` blocks. The data lake (and its
three containers) already met the baseline: **0 to add, 0 to change,
0 to destroy**. The site account was lifted to it, with two in-place
changes (`default_to_oauth_authentication` on, `local_user_enabled`
off) and no replacement.
