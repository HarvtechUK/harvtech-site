# key-vault

A Key Vault for application secrets, with the security baseline **fixed
in code**: Azure RBAC only, purge protection, 90-day soft delete, no
ARM/VM/disk-encryption side doors, and an audit log that cannot be left
off.

The module **creates no secrets, on purpose**. Anything Terraform writes
into a vault (`azurerm_key_vault_secret`) is also written to Terraform
state in plaintext, which turns the state file into a second, weaker
copy of every secret. So values are set by an operator or a rotation
process (see [Rotating a secret](#rotating-a-secret)), and Terraform only
ever handles references to them. `modules/container-app` is the other
half of that design: it accepts Key Vault references and nothing else.

## Usage

```hcl
data "azurerm_client_config" "current" {}

module "key_vault" {
  source                     = "../modules/key-vault"
  name                       = module.naming.key_vault
  resource_group_name        = module.resource_group.name
  location                   = module.resource_group.location
  tags                       = module.tags.tags
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  role_assignments = {
    api_secrets_read = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = module.api.principal_id
      principal_type             = "ServicePrincipal"
    }
  }
}
```

## Security baseline (not configurable)

| Setting | Value | Why |
|---|---|---|
| `rbac_authorization_enabled` | `true` | Access policies are a vault-local permission system that RBAC tooling, PIM and access reviews cannot see. |
| `purge_protection_enabled` | `true` | Nobody, including an attacker holding Owner, can skip the recovery window. **Irreversible**, and a deleted vault's name stays reserved until the window ends. |
| `soft_delete_retention_days` | `90` | The maximum recovery window. |
| `enabled_for_deployment` / `_disk_encryption` / `_template_deployment` | `false` | Side doors that let ARM, VMs or disk encryption read secrets without an RBAC grant. |
| Audit log | always on | Every secret read and write, and by whom, goes to the Log Analytics workspace you must pass in. A vault that cannot answer "who read this secret?" fails the first question in any incident. |

## Trade-offs (inputs with safe defaults)

| Input | Default | Override when |
|---|---|---|
| `public_network_access_enabled` | `false` | A consumer cannot reach the vault privately. The portal does this: its Container Apps environment is not VNet-integrated, and Container Apps is not a Key Vault trusted service. |
| `firewall_ip_rules` / `firewall_subnet_ids` | `[]` | Public access is on and you can name the callers. Any rule switches the default action to **Deny**; trusted Azure services always bypass. |
| `sku_name` | `standard` | You need HSM-backed keys (`premium`). |

Plus the house guardrails shared with the other modules: CAF `kv`
prefix, UK regions only by default, mandatory tag keys, and no standing
Owner, User Access Administrator or Role Based Access Control
Administrator grants.

## Rotating a secret

Values never pass through Terraform, CI logs or shell history. The
operator gets write access just in time, sets the value from a pipe, and
gives the access back:

```bash
VAULT=kvharvtechportalprduks01
ME=$(az ad signed-in-user show --query id -o tsv)
SCOPE=$(az keyvault show -n "$VAULT" --query id -o tsv)

# 1. Just-in-time write access (Secrets Officer can set values, not manage access)
az role assignment create --assignee "$ME" --role "Key Vault Secrets Officer" --scope "$SCOPE"

# 2. Generate and store in one pipe. The value is never printed or saved.
python3 -c 'import secrets; print(secrets.token_urlsafe(48), end="")' \
  | az keyvault secret set --vault-name "$VAULT" --name session-secret \
      --file /dev/stdin --content-type "text/plain" --query id -o tsv

# 3. Give the access back
az role assignment delete --assignee "$ME" --role "Key Vault Secrets Officer" --scope "$SCOPE"
```

Apps reference secrets **without a version**, so they pick up the new
value on their next revision (or on Container Apps' periodic refresh).
RBAC changes can take a few minutes to propagate before step 2 works.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | `kv…`, 3-24 letters, digits and single hyphens. |
| `resource_group_name` | `string` | required | Normally `module.resource_group.name`. |
| `location` | `string` | required | Must be in `allowed_locations`. |
| `tags` | `map(string)` | required | Normally `module.tags.tags`. |
| `tenant_id` | `string` | required | Normally `data.azurerm_client_config.current.tenant_id`. |
| `log_analytics_workspace_id` | `string` | required | Receives the audit log. |
| `allowed_locations` | `list(string)` | `["uksouth", "ukwest"]` | Regions the module will deploy to. |
| `required_tag_keys` | `list(string)` | ownership and cost keys | Tag keys the vault must carry. |
| `sku_name` | `string` | `standard` | `standard` or `premium`. |
| `public_network_access_enabled` | `bool` | `false` | See trade-offs. |
| `firewall_ip_rules` | `list(string)` | `[]` | IPs or CIDR ranges; needs public access on. |
| `firewall_subnet_ids` | `list(string)` | `[]` | Subnets with the Key Vault service endpoint. |
| `role_assignments` | `map(object)` | `{}` | Same shape as the other modules. |

## Outputs

| Name | Description |
|---|---|
| `id` | Vault ID, for role assignments. |
| `name` | For `az keyvault` calls. |
| `vault_uri` | Versionless secret IDs are `"<vault_uri>secrets/<name>"`. |
| `role_assignment_ids` | Keyed like `role_assignments`. |

## Scanner notes

Two Checkov behaviours shaped this module, both found by reproducing the
CI scan locally:

- **Checkov stops resolving a variable whose `validation` references
  another variable**, and then reports checks that depend on it as
  passed. The firewall inputs therefore only have self-contained
  validation; the "rules need public access" rule is a `precondition`
  on the vault instead.
- `network_acls` is always present with plain values rather than a
  dynamic block, so the recorded default action is the real one: Allow
  for a public vault with no rules. A fully private vault may still be
  reported as failing CKV_AZURE_109, because Checkov cannot evaluate the
  condition; that error is in the strict direction, and the real default
  action is Deny.

## Testing

```bash
terraform -chdir=modules/key-vault init -backend=false
terraform -chdir=modules/key-vault test
```

15 runs against a mocked azurerm provider. Mutation-checked: turning off
RBAC, purge protection or the audit log, opening a side door, or making
the firewall record Deny when it is really open each fails the run that
guards it.
