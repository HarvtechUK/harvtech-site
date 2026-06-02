---
title: Azure data-platform HLD
description: Lakehouse-style data platform alongside the main site — ADLS Gen2, Cosmos DB, Data Factory, Databricks. Built cheap to demonstrate the IaC patterns from prior real-world experience.
category: architecture
order: 20
updated: 2026-06-02
status: living
---

## Why this exists

I've worked with Azure's data services at multiple contracts — Brit Insurance and Tokio Marine Kiln in the most recent stretch. Showing the IaC pattern for those services on the same site that proves my Front Door / WAF / Conditional Access work reads more credibly than just listing them on a CV.

The catch: the data services normally cost real money to run. Databricks compute, Synapse SQL pools, Fabric capacities — all designed to scale, all priced accordingly. So the trick is **deploy the resources** (where it's cheap), **don't run the workloads** (where it isn't), and **document what running them would look like** for the parts that aren't deployable cheap at all.

Total ongoing cost of everything in `data-platform/`: **under £1/month**.

## Architecture

A medallion-architecture lakehouse with OLTP and orchestration around it.

```
                          ┌──────────────────────────┐
                          │  Azure Data Factory       │
                          │  (orchestrator stub)      │
                          │  SystemAssigned identity  │
                          └──────────┬───────────────┘
                                     │ reads
                                     ▼
   ┌──────────────────────────────────────────────────────┐
   │  ADLS Gen2 storage account                            │
   │  (Hierarchical Namespace ON)                          │
   │                                                       │
   │   raw       cleansed      curated                     │
   │   bronze    silver        gold                        │
   └──────────────────────────────────────────────────────┘
                                     ▲
                                     │ reads / writes
                                     │
   ┌──────────────────────────────────────────────────────┐
   │  Azure Databricks workspace (Standard tier)          │
   │  (workspace exists; no clusters running)             │
   └──────────────────────────────────────────────────────┘

   ┌──────────────────────────┐
   │  Cosmos DB (SQL API)      │  ← OLTP / API-backing store
   │  free tier (1000 RU/s)    │     completely separate from
   │  Session consistency      │     the analytics path above
   └──────────────────────────┘
```

The analytics side and the OLTP side aren't connected in this demo — adding a CDC pipeline from Cosmos to the lake (via Change Feed → ADF or Databricks Auto Loader) would be a natural next step.

## Component breakdown

### ADLS Gen2 storage account

- **Hierarchical namespace** (`is_hns_enabled = true`) — the flag that makes a storage account a Data Lake Storage Gen2 account rather than a normal Blob account. POSIX-style paths, ACLs, and a `dfs.core.windows.net` endpoint for Spark/Databricks-flavoured filesystem access.
- **Three containers**: `raw` (bronze) for source data verbatim, `cleansed` (silver) for validated/typed records, `curated` (gold) for business-ready aggregates. The canonical medallion layout.
- **Lockdown defaults**: TLS 1.2 minimum, shared-key auth disabled, infrastructure encryption on at create time (unlike the site SA, which would have required replacement to enable retroactively), 7-day soft-delete on both blobs and containers, SAS expiration policy enforced.

### Cosmos DB

- **SQL (Core) API** — most common Cosmos flavour. Document model, SQL-ish query syntax.
- **Free tier claimed**: 1000 RU/s and 25 GB free for life on this single account. Microsoft restricts this to one account per subscription; the slot was unburnt so we took it.
- **Session consistency**: read-your-writes, lower latency, lower RU cost than Strong / BoundedStaleness. Right default for most user-facing apps.
- **Local auth disabled**: master keys and connection strings can't be used — anyone reading or writing comes via Entra ID. Same discipline as the site storage account.
- **One database / container** today (`app` / `sessions`), driven by a two-level map in `env/prd.tfvars`. Adding a database or container is a tfvars edit.

### Azure Data Factory

- **Stub only**. The workspace resource is free; cost only accrues when pipelines actually run.
- **SystemAssigned identity** pre-granted `Storage Blob Data Reader` on the datalake — when future pipelines land, they auth via Entra rather than connection strings.
- **Public managed IR** — cheapest option, fine for a portfolio demo. A real engagement would use a Self-Hosted IR or Managed VNet IR depending on the network story.

### Databricks workspace

- **Standard tier**. Workspace itself has no ongoing cost; cost lives in clusters when they run.
- **Managed RG name pinned** so it doesn't get a different GUID suffix on every recreate.
- **No clusters / cluster policies in code** — would be the next layer if real workloads landed.
- **Public network access**. A real engagement would use VNet injection plus Private Link to the Databricks control plane.

## What's deliberately NOT here

| Service | Why not |
|---|---|
| **Microsoft Fabric** | No first-class Terraform support for resource-level config, and the only free path is a 60-day trial that expires. Captured as prior experience here rather than half-broken IaC. |
| **Azure Synapse Analytics** | Heavy overlap with Databricks for the lakehouse story; picking one keeps the showcase focused. Databricks reads more cleanly on a CV. |
| **Azure Stream Analytics** | Streaming units cost ~£40/mo even idle. Wrong cost profile for a portfolio. |
| **Real pipelines / notebooks / queries** | Each would accrue cost when running. The IaC pattern is the demo; running workloads is a separate decision driven by an actual business need. |
| **Private endpoints / VNet integration on this side** | Adding a VNet + private endpoints for each service would multiply the per-month cost. Documented as the productionisation path. |

## Cost summary

| Item | Monthly |
|---|---|
| ADLS Gen2 storage account (empty) | ~£0.10 |
| Cosmos DB (free tier) | **£0** |
| Data Factory (no pipeline runs) | **£0** |
| Databricks workspace (no clusters) | **£0** |
| **Total** | **< £1/mo** |

The number-one cost trap to be aware of: an accidentally-spun-up Databricks cluster left running overnight adds £20–30 quickly. Worth setting up a Cost Anomaly Alert on the data-platform RG specifically if running workloads is ever a real plan.

## Productionisation path

If this were a client engagement and not a portfolio:

1. **Private endpoints on everything** — Cosmos, ADLS, ADF, Databricks. Plus a VNet, private DNS zones, NSG rules.
2. **Customer-managed keys** for the datalake — currently MS-managed; CMK would route through Key Vault.
3. **Databricks Premium** — Unity Catalog, RBAC, audit logs.
4. **Diagnostic settings** on all of them flowing to a Log Analytics workspace (same followup as for the site stack).
5. **Pipelines under source control** — ADF supports git integration for pipelines/datasets/linked services. Would link to a separate `data-platform-pipelines/` repo or directory.
6. **Cost guardrails** — Budgets + alerts at the RG level so a runaway cluster gets caught.

Each of those is a small Terraform change in its own right. None of them belong on a portfolio site burning real money.
