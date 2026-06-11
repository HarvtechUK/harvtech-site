# naming

Central naming convention for every Azure resource in this repo. One
module call per stack; every resource name comes from an output, so the
convention lives in exactly one place.

## Pattern

```
<caf-abbrev>-<project>-<workload>-<env>-<region>-<ordinal>
```

| Example input | Output |
|---|---|
| `rg` + harvtech/site/prd/uksouth/01 | `rg-harvtech-site-prd-uks-01` |
| `st` (compact) | `stharvtechsiteprduks01` |
| `afd` | `afd-harvtech-site-prd-uks-01` |
| `fdfp` (compact) | `fdfpharvtechsiteprduks01` |

Abbreviations follow the [CAF resource-abbreviation list](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).
Types whose names forbid hyphens (storage accounts, Front Door WAF
policies, key vaults at our length budget) use the same parts compacted.

## Usage

```hcl
module "naming" {
  source      = "../modules/naming"
  project     = var.project     # "harvtech"
  workload    = "site"
  environment = var.environment # "prd"
  location    = var.location    # "uksouth"
}

resource "azurerm_resource_group" "site" {
  name = module.naming.resource_group
  # ...
}
```

## Adding a resource type

One output block in `outputs.tf`: pick the abbreviation from the CAF
list, use `local.hyphenated` (or `local.compact` for no-hyphen types),
and add a `check` block in `main.tf` if the type has a length limit
tighter than ~60 characters.

## Adding a region

One entry in the `region_short` map in `main.tf` plus the matching
entry in the `location` variable validation.
