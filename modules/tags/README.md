# tags

Standard tag set for every taggable resource in this repo. One module
call per stack; resources reference `module.tags.tags`.

## Standard set

| Key | Value | Why |
|---|---|---|
| `project` | `harvtech` | Cost roll-up across all workloads |
| `workload` | `site` / `data` / `dns` | Which stack owns it |
| `environment` | `prd` | Environment filtering |
| `managed_by` | `terraform` | "Do not hand-edit in the portal" |
| `repo` | `HarvtechUK/harvtech-site` | Portal → source in one hop |
| `cost_centre` | `personal` | Billing attribution |
| `owner` | `alex@harvtech.co.uk` | Who to call during an incident |

## Usage

```hcl
module "tags" {
  source      = "../modules/tags"
  project     = var.project
  workload    = "site"
  environment = var.environment

  extra_tags = {
    data_classification = "public" # optional stack-specific additions
  }
}

resource "azurerm_resource_group" "site" {
  # ...
  tags = module.tags.tags
}
```

Tag changes are in-place updates in Azure — adopting this module never
forces a replacement. `extra_tags` wins on key collision, so a stack
can deliberately override a standard value as well as extend the set.
