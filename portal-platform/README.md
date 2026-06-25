# portal-platform

Azure platform for the multi-client client portal (timesheets +
engagement approval). The application itself is the FastAPI app in
[`portal/`](../portal); this stack is the Azure it runs on. See
[`docs/architecture/portal-hld.md`](../docs/architecture/portal-hld.md)
for the full design.

## What this stack provisions

| Resource | Purpose |
|---|---|
| Resource group | `rg-harvtech-portal-prd-uks-01` |
| Cosmos DB (serverless, SQL API) | Client data — dedicated account, no keys (Entra RBAC only) |
| Container Registry (Basic) | Holds the portal's container image |
| Container Apps Environment | The runtime boundary; streams logs to Log Analytics |
| Container App (scale-to-zero) | Runs the FastAPI app; system-assigned managed identity |
| Cosmos SQL role assignment | App MI → "Built-in Data Contributor" (data-plane, no control-plane) |
| AcrPull role assignment | App MI → pull images from the registry, keylessly |
| App Insights + Log Analytics | Observability |

## Security posture

- **No keys anywhere.** The Container App's managed identity does double
  duty: pulling the image from ACR (AcrPull) and reading/writing Cosmos
  (data-plane RBAC). Cosmos local auth is disabled; ACR admin user is off.
- Real client PII / financial records — tagged `data_classification =
  confidential`, isolated from the analytics-demo data-platform account.

## The image: placeholder → real

On first apply the Container App runs a public hello-world image, because
our image isn't in ACR yet. The deploy workflow then builds `portal/`,
pushes it to ACR, and updates the app. A `lifecycle { ignore_changes }`
on the image hands that tag to CI, so Terraform manages everything about
the app *except* which image version is running.

## Custom domain (Phase 1.5)

`portal.harvtech.co.uk` is bound after this stack's first apply, so the
Container App's ingress FQDN exists in remote state for the CNAME to
target:

1. This stack applied → `container_app_fqdn` in outputs.
2. `dns/` creates the `portal` CNAME → that FQDN (reads this stack's
   remote state).
3. Add `azurerm_container_app_custom_domain` here, which validates against
   the now-present CNAME and gets a managed certificate.

## Not in this stack (later phases)

- Custom domain binding + dns CNAME (Phase 1.5, sequenced above)
- Entra External ID app registrations + auth wiring (Phase 2)
- The Dockerfile and deploy workflow that build/push/deploy the image
