# resource-group

A resource group with the house rules enforced at `terraform plan` time,
before anything reaches Azure: UK regions only by default, CAF naming,
mandatory ownership and cost tags, an optional management lock, and role
assignments that refuse standing privileged access.

The interface mirrors [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
(`lock`, `role_assignments` with `role_definition_id_or_name`), so moving
to `Azure/avm-res-resources-resourcegroup` later would be a source change
rather than a rewrite. The reasons for owning the module anyway are in
[docs/decisions/own-modules-avm-shaped](../../site/src/content/docs/decisions/own-modules-avm-shaped.md).

## Usage

```hcl
module "resource_group" {
  source   = "../modules/resource-group"
  name     = module.naming.resource_group
  location = var.location
  tags     = module.tags.tags
}

resource "azurerm_storage_account" "site" {
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  # ...
}
```

With the optional features:

```hcl
module "resource_group" {
  source   = "../modules/resource-group"
  name     = module.naming.resource_group
  location = var.location
  tags     = module.tags.tags

  lock = {
    kind  = "CanNotDelete"
    notes = "Holds client data. Remove through code, not the portal."
  }

  role_assignments = {
    auditors_read = {
      role_definition_id_or_name = "Reader"
      principal_id               = var.auditors_group_object_id
      principal_type             = "Group"
    }
  }
}
```

## Opinions baked in

| Guardrail | Why | Escape hatch |
|---|---|---|
| **UK regions only** (`uksouth`, `ukwest`) | Regulated UK clients usually need data to stay in the UK, and a typo should fail the plan rather than quietly deploy to `eastus`. Display names (`UK South`) are accepted. | Widen `allowed_locations` deliberately. |
| **CAF `rg-` prefix** and Azure's name rules (90 chars, allowed characters, no trailing period) | Names come from `modules/naming`; the check catches hand-typed names and fails at plan rather than mid-apply. | None. Use `module.naming.resource_group`. |
| **Mandatory tag keys** (`project`, `workload`, `environment`, `owner`, `cost_centre`, `managed_by`) | An unowned or uncosted resource group should never exist, and finding out from a cost report is too late. | Change `required_tag_keys`. |
| **No standing privileged roles.** Owner, User Access Administrator and Role Based Access Control Administrator are refused, by name or by role definition ID. | Permanent privileged grants are a standard audit finding. That access belongs in PIM as an eligible, time-bound assignment. | None in this module, on purpose. |
| **`principal_id` must be a GUID** | Catches a UPN or display name at plan time instead of as an API error mid-apply. | None. |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | Resource group name (`rg-…`). |
| `location` | `string` | required | Region; must be in `allowed_locations`. |
| `tags` | `map(string)` | required | Normally `module.tags.tags`; must contain `required_tag_keys`. |
| `allowed_locations` | `list(string)` | `["uksouth", "ukwest"]` | Regions the module will deploy to, in short form. |
| `required_tag_keys` | `list(string)` | ownership and cost keys | Tag keys every resource group must carry. |
| `lock` | `object` | `null` | `{ kind = "CanNotDelete" \| "ReadOnly", name?, notes? }`. |
| `role_assignments` | `map(object)` | `{}` | Keyed by a stable label; see `variables.tf` for fields. |

## Outputs

| Name | Description |
|---|---|
| `id` | Resource group ID, for scoping role assignments, policy and budgets. |
| `name` | For `resource_group_name` on resources deployed into the group. |
| `location` | Short-form region, for co-locating resources. |
| `lock_id` | Lock ID, or `null` with no lock. |
| `role_assignment_ids` | Assignment IDs, keyed like `role_assignments`. |

## Before turning on a lock

- Creating a lock needs `Microsoft.Authorization/locks/write` (Owner or
  User Access Administrator). A Contributor-only deployment identity,
  which is what this repo's CI uses, cannot create one.
- A `CanNotDelete` lock on the group also stops Terraform deleting or
  replacing **anything inside it**. Any change that forces a replacement
  then fails until the lock is lifted, which is the point, but plan for it.
- `ReadOnly` blocks more than it looks like it should (for example,
  listing storage account keys is a POST). Prefer `CanNotDelete`.

## Testing

Native `terraform test` with a mocked azurerm provider, so the suite
needs no Azure credentials and deploys nothing:

```bash
terraform -chdir=modules/resource-group init -backend=false
terraform -chdir=modules/resource-group test
```

15 runs cover the defaults, each guardrail rejecting what it should
(`expect_failures`), the escape hatches, and the lock and role
assignment wiring. CI runs the same suite on every pull request that
touches `modules/` (`.github/workflows/modules.yml`).

## Adopting without downtime

This module was adopted by three live stacks with `moved` blocks, so the
existing resource groups changed Terraform address but not Azure
identity. Each stack's adoption plan showed
**0 to add, 0 to change, 0 to destroy**. See `infra/moves.tf`,
`portal-platform/moves.tf` and `data-platform/moves.tf`.
