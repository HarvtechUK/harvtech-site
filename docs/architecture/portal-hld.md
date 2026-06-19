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
                    │   Azure Static Web App     │  static portal UI (Astro)
                    │   (Standard)               │  + built-in auth at the edge
                    └─────────────┬─────────────┘
                       linked backend │ (/api/*)
                    ┌─────────────▼─────────────┐
                    │   Azure Function App       │  API — runs in OUR subscription
                    │   (Linux, consumption)     │  system-assigned managed identity
                    └─────────────┬─────────────┘
                   managed identity │ (data-plane RBAC, no keys)
                    ┌─────────────▼─────────────┐
                    │   Cosmos DB (SQL API)      │  clients / users / engagements / timesheets
                    └───────────────────────────┘

      Identity: Microsoft Entra External ID (CIAM) — customer sign-in,
      isolated from the corporate Entra tenant.
```

**Why these choices:**

- **Static Web Apps** gives us authentication *as configuration* rather
  than code. As a security consultancy, using battle-tested auth we
  didn't write is the right reputational call — rolling our own login is
  the fastest way to a CVE with our name on it.
- **Linked Function App in our own subscription** (not SWA's free managed
  Functions) so the API can use a **system-assigned managed identity** to
  reach Cosmos with **no connection strings or keys anywhere** —
  consistent with the no-local-auth stance already taken on Cosmos
  (`local_authentication_disabled = true`) and the site storage account.
- **Entra External ID** (the CIAM successor to Azure AD B2C) keeps client
  user accounts in a dedicated customer directory, isolated from the
  HarvTech corporate tenant and its break-glass / CA policies.
- **Cosmos SQL API** — already understood and provisioned in this repo;
  cheap at this volume; partitioning gives clean per-tenant isolation.

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
| Static Web App | Standard (needed for linked backend) | ~£7 |
| Function App | Linux consumption | ~£0 (free grant) |
| Cosmos DB | see decision D1 | £0–5 |
| Entra External ID | first 50k MAU free | £0 |
| **Total** | | **~£7–12/mo** |

## 7. Open decisions (need Alex's call before Phase 1 build)

**D1 — Where does portal data live?**
The free-tier Cosmos slot is already claimed by the `data-platform`
stack (framed as an analytics *demo*). Two options:
- **(a) Reuse the data-platform Cosmos account** — £0, but mixes real
  client PII + financial records (7-yr retention) into the demo platform.
- **(b) Dedicated serverless Cosmos account in the portal stack**
  *(recommended)* — clean separation of real client data from the demo,
  proper blast-radius isolation, pay-per-use (~£a few/mo at this volume).
  Loses free tier, but the separation is the defensible posture for data
  you're legally accountable for.

**D2 — Identity: External ID vs B2B guests?**
- **(a) Entra External ID** *(recommended for "reusable platform")* —
  proper customer directory, sign-up/sign-in flows, scales to many
  clients. Needs interactive tenant setup (see runbook).
- **(b) B2B guest accounts in the corporate tenant** — lighter, free, but
  every client user becomes a guest in HarvTech's own tenant. Fine for a
  handful of clients; doesn't scale as cleanly.

**D3 — Subdomain confirm:** `portal.harvtech.co.uk` (vs `app.` / `clients.`).

## 8. Phased delivery

| Phase | What | Who | Blocked by |
|---|---|---|---|
| 0 | This HLD + External ID runbook | done | — |
| 1 | `portal-platform` Terraform stack (SWA, Function App + MI, Cosmos RBAC, DNS, workflow) | Claude | D1, D2, D3 |
| 2 | Wire External ID auth (app regs, SWA config, role mapping) | Claude + Alex (tenant) | runbook done |
| 3 | API — Functions, managed identity to Cosmos, role/clientId scoping | Claude | 1, 2 |
| 4 | Portal UI — dashboard, submit, approve, PDF export | Claude | 3 |
| 5 | Onboarding flow + seed first client (40 days @ £650) | Claude + Alex | 4 |

Each phase is its own PR through `dev → main`, same as every other
change in this repo. Nothing touches the live marketing site.
