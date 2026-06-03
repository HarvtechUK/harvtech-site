# data-platform/

Terraform stack for the Azure data-platform showcase: a medallion-style data lake plus its closest neighbours.

## What's in here

| Service | Resource | What it demonstrates |
|---|---|---|
| **ADLS Gen2** | `azurerm_storage_account.datalake` + 3 containers (`raw`, `cleansed`, `curated`) | Lakehouse foundation. Bronze/silver/gold medallion layout, HNS on. |
| **Cosmos DB** | `azurerm_cosmosdb_account.this` + database + container | OLTP / API-backing store. Free-tier discount claimed (1000 RU/s + 25 GB free for life). |
| **Data Factory** | `azurerm_data_factory.this` | Orchestrator stub — no pipelines yet, but the workspace exists and has a SystemAssigned identity pre-granted Storage Blob Data Reader on the datalake. |
| **Databricks workspace** | `azurerm_databricks_workspace.this` | Lakehouse compute layer. Premium SKU (Azure deprecated Standard for new workspaces in 2026), no clusters running. |

## Why this exists

Shows the IaC pattern for Azure data services I've worked with at prior contracts (Brit, Tokio Marine Kiln). The deployed resources are minimal stubs — what's interesting is the Terraform.

## State

- Backend: same Azure Storage as the other stacks
- State key: `data-platform.tfstate`

## Service principal

Uses the existing `sp-github-harvtech-site` (Contributor at subscription scope). No new SP needed — data-platform doesn't have any Microsoft Graph dependencies the way `identity/` does.

## Cost

| Item | Monthly |
|---|---|
| ADLS Gen2 storage account (empty) | ~£0.10 |
| Cosmos DB free tier | **£0** |
| Data Factory (no pipeline runs) | **£0** |
| Databricks workspace (no clusters) | **£0** |
| **Total** | **< £1/mo** |

If you spin up a Databricks cluster, that's where the real money lives. The IaC pattern is set; running workloads is a separate decision.

## Scaling

- New medallion layer: add an entry to `var.lakehouse_layers` in `env/prd.tfvars`
- New Cosmos database or container: add a map entry to `var.cosmos_databases`
- New environment: add `env/dev.tfvars` next to `prd.tfvars`, drive via the workflow's `TFVARS` env var

## What's deliberately NOT here

- **Synapse Analytics** — overlaps with Databricks. Picked Databricks for the CV-readability.
- **Microsoft Fabric** — no per-resource Terraform support yet and the only "free" path is a 60-day trial that expires. Captured in the wiki as prior-experience.
- **Stream Analytics** — streaming units cost £40+/month even idle.
- **Real pipelines / notebooks / queries** — would all add cost when they run. The IaC pattern is the demo; running workloads is a separate decision.
