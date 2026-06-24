# Client Portal — High-Level Design

**Status:** Draft / awaiting decisions D1–D3
**Author:** Alex Harvey
**Last updated:** June 2026

A multi-client timesheet and engagement portal where clients log in to
review and approve consultancy days delivered, backing HarvTech's
invoicing. Built reusable from day one — the first client (40 days @
£650) is the first tenant, not a one-off.

---

## 1. Why not just add it to the site

The marketing site is a **static** site (HTML on Storage `$web` behind
Front Door). A static site cannot authenticate users, run server logic,
or hold data. A portal needs all three. So the portal is a **separate
application on its own subdomain** — `portal.harvtech.co.uk` — leaving
the live marketing site completely untouched (zero risk to what's
already working).

## 2. Architecture

```
                          portal.harvtech.co.uk
                                  │
                    ┌─────────────▼─────────────┐
                    │   Azure Container App      │  one FastAPI app (Python):
                    │   (scale to zero)          │  API + server-rendered UI
                    └──────┬──────────────┬──────┘  system-assigned managed identity
            pull image     │              │  data-plane RBAC, no keys
       ┌─────────▼────────┐ │     ┌────────▼──────────┐
       │ Container        │ │     │ Cosmos DB (SQL)   │  clients / users /
       │ Registry (Basic) │ │     │ (serverless)      │  engagements / timesheets
       └──────────────────┘ │     └───────────────────┘
                            │
              built & pushed by the deploy workflow

      Identity: Microsoft Entra External ID (CIAM) — customer sign-in,
      isolated from the corporate Entra tenant. The app handles the OIDC
      flow itself (MSAL for Python).
```

**Why these choices:**

- **Container Apps + FastAPI** — the app is built in Python (a deliberate
  learning goal), so a single containerised FastAPI app serving both the
  API and the server-rendered UI is the most cohesive, transferable shape.
  Scales to zero when idle (pay nothing at rest), and we get Docker +
  Container Apps experience that's directly useful to clients.
- **System-assigned managed identity** does double duty: it pulls the
  image from our registry (AcrPull) and reaches Cosmos (data-plane RBAC),
  so there are **no keys or connection strings anywhere** — consistent
  with the no-local-auth stance on Cosmos and the site storage account.
- **Container Registry, Basic SKU** — first-party image, pulled keylessly;
  Premium features (geo-replication, scanning, content trust) aren't worth
  ~10× the cost for one low-traffic app.
- **Entra External ID** (the CIAM successor to Azure AD B2C) keeps client
  user accounts in a dedicated customer directory, isolated from the
  HarvTech corporate tenant and its break-glass / CA policies. Because the
  app owns the OIDC flow, the login code is ours — but it's standard MSAL,
  not hand-rolled crypto.
- **Cosmos SQL API** — already understood and provisioned in this repo;
  cheap (serverless) at this volume; partitioning gives clean per-tenant
  isolation.

## 3. Data model (Cosmos SQL API, database `portal`)

| Container | Partition key | Purpose |
|---|---|---|
| `clients` | `/id` | One doc per client org |
| `users` | `/id` | Maps External ID subject → role + clientId |
| `engagements` | `/clientId` | An engagement: day rate, total days, PO |
| `timesheets` | `/clientId` | A period's submitted/approved days |

Partitioning `engagements` and `timesheets` by `/clientId` gives
**per-tenant isolation** (every query is naturally scoped to one client)
and cheap point reads.

**`engagements`**
```jsonc
{
  "id": "eng-2026-001",
  "clientId": "client-acme",
  "title": "Azure landing zone — phase 1",
  "dayRate": 650,
  "currency": "GBP",
  "totalDays": 40,
  "poNumber": "PO-12345",
  "startDate": "2026-06-01",
  "status": "active",          // active | closed
  "contractorId": "alex"
}
```

**`timesheets`**
```jsonc
{
  "id": "ts-2026-06-client-acme",
  "clientId": "client-acme",
  "engagementId": "eng-2026-001",
  "contractorId": "alex",
  "period": "2026-06",
  "entries": [
    { "date": "2026-06-03", "days": 1,   "notes": "Landing zone design" },
    { "date": "2026-06-04", "days": 0.5, "notes": "Stakeholder workshop" }
  ],
  "status": "submitted",       // draft | submitted | approved | rejected
  "submittedAt": "2026-06-30T17:00:00Z",
  "approvedBy": null,
  "approvedAt": null,
  "totalDays": 1.5,
  "totalValue": 975
}
```

Derived figures (days remaining, value invoiced) are computed from
approved timesheets against the engagement's `totalDays` — never stored
denormalised, so they can't drift.

## 4. Roles & authorisation

| Role | Can |
|---|---|
| `contractor` | Create/submit timesheets across all clients (this is Alex) |
| `client_approver` | Read + approve/reject timesheets **for their own client only** |
| `admin` | Manage clients & engagements (also Alex) |

The API maps the token's subject to a `users` doc carrying `role` and
`clientId`, and **enforces clientId scoping server-side on every call** —
the client identity is never trusted from the request body. Defence in
depth: a `client_approver` token can only ever touch its own client's
partition.

## 5. IR35 framing

Deliberate wording throughout: this records **delivered consultancy days
approved for invoicing**, not "hours worked under supervision." A B2B
client signing off delivered days is normal outside-IR35 evidence of
services rendered; an hourly, directed timesheet reads the wrong way for
status. UI copy, field names (`days` not `hours`), and PDF headings all
follow this.

## 6. Cost (incremental)

| Component | Tier | ~£/mo |
|---|---|---|
| Container App | Consumption, scale-to-zero | ~£0–5 |
| Container Registry | Basic | ~£4 |
| Cosmos DB | Serverless (dedicated account) | ~£0–5 |
| Log Analytics + App Insights | Pay-as-you-go, low volume | ~£0–2 |
| Entra External ID | first 50k MAU free | £0 |
| **Total** | | **~£8–16/mo** |

## 7. Decisions (resolved)

- **D1 — Data store:** dedicated **serverless Cosmos account** in the
  portal stack. Real client PII / financial records get their own blast
  radius, separate from the analytics-demo data platform.
- **D2 — Identity:** **Entra External ID** (CIAM) — reusable across many
  clients. Interactive tenant setup in the runbook.
- **D3 — Subdomain:** `portal.harvtech.co.uk`.
- **Stack/runtime** (decided once the app went Python): **FastAPI**,
  containerised, on **Azure Container Apps** — not the originally-sketched
  Static Web App + Functions. One Python app, Docker, scale-to-zero.

## 8. Phased delivery

| Phase | What | Status |
|---|---|---|
| 0 | This HLD + External ID runbook | done |
| 1 | `portal-platform` Terraform stack (Container Apps, ACR, Cosmos + MI RBAC, observability) | done |
| 1.5 | Bind `portal.harvtech.co.uk` to the Container App + dns CNAME | after 1 applies |
| App | FastAPI app — models, API, Cosmos data layer, Jinja UI | in progress (built; see `portal/`) |
| 2 | Wire Entra External ID auth + per-client role scoping | after runbook + app |
| Deploy | Dockerfile + build/push to ACR + deploy workflow | next |
| 5 | Onboarding flow + seed first client (40 days @ £650) | after deploy |

Each phase is its own PR through `dev → main`, same as every other
change in this repo. Nothing touches the live marketing site.
