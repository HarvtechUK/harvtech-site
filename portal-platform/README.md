# portal-platform

Azure platform for the multi-client client portal (timesheets +
engagement approval). See [`docs/architecture/portal-hld.md`](../docs/architecture/portal-hld.md)
for the full design.

## What this stack provisions

| Resource | Purpose |
|---|---|
| Resource group | `rg-harvtech-portal-prd-uks-01` |
| Cosmos DB (serverless, SQL API) | Client data — dedicated account, no keys (Entra RBAC only) |
| Static Web App (Standard) | Portal UI + edge auth (custom domain bound in Phase 1.5) |
| Function App (Linux consumption) | Portal API, system-assigned managed identity |
| Cosmos SQL role assignment | Function MI → "Built-in Data Contributor" (data-plane, no control-plane) |
| App Insights + Log Analytics | Observability |

## Security posture

- **No keys to client data.** The Function App reaches Cosmos via its
  managed identity and a data-plane role assignment. Cosmos local auth
  is disabled.
- The Functions *runtime* backing storage account uses a key for
  `AzureWebJobsStorage` (a Consumption-plan requirement) but holds no
  business data. Candidate to move to Flex Consumption later.
- Real client PII / financial records — tagged `data_classification =
  confidential`, isolated from the analytics-demo data-platform account.

## Custom domain (Phase 1.5)

`portal.harvtech.co.uk` is bound after this stack's first apply, so the
SWA default hostname exists in remote state for the CNAME to target:

1. This stack applied → SWA default hostname in outputs.
2. `dns/` creates `portal` CNAME → SWA default hostname (reads this
   stack's remote state).
3. Add `azurerm_static_web_app_custom_domain` here (cname-delegation),
   which validates against the now-present CNAME.

## Not in this stack (later phases)

- Custom domain binding + dns CNAME (Phase 1.5, sequenced above)
- Entra External ID app registrations + SWA auth config (Phase 2)
- The Function code and the portal UI (Phases 3–4)
