# Runbook — Microsoft Entra External ID setup (portal auth)

The one part of the portal build that can't be fully automated:
standing up the customer identity tenant. Tenant creation and the
initial admin consent need an interactive Global Administrator, so they
live here as steps for Alex. Everything that *can* be Terraformed (app
registrations, where the `azuread` provider supports them) is wired in
Phase 2 against the tenant this runbook produces.

> Do **not** use the corporate Entra tenant for client users. External
> ID is a separate directory so client accounts never land in the tenant
> that holds the break-glass account and CA policies.

## Prerequisites

- Global Administrator on the Azure subscription (your normal admin
  account — **not** the break-glass account).
- `az` CLI logged in: `az login`.

## 1. Create the External ID tenant

Portal → **Microsoft Entra External ID** → *Create a tenant* →
**External** configuration (customer-facing, CIAM), not "Workforce".

- Tenant name: `harvtechclients` (or similar)
- Domain: `harvtechclients.onmicrosoft.com`
- Region: United Kingdom / Europe
- Link it to the subscription for billing (first 50k MAU free).

Record the **tenant ID** and **primary domain** — they feed the
Phase 2 Terraform variables.

## 2. Register the portal applications

In the new External ID tenant, App registrations → *New registration*:

**a) Portal SPA** (`harvtech-portal-spa`)
- Redirect URI (SPA): `https://portal.harvtech.co.uk/.auth/login/aad/callback`
- Note the **Application (client) ID**.

**b) Portal API** (`harvtech-portal-api`)
- Expose an API → set Application ID URI → add a scope `access_as_user`.
- The SPA registration → API permissions → add the API's `access_as_user`,
  grant admin consent.

(Phase 2 will move these into `azuread` Terraform where the provider
supports the External ID directory; capture the IDs here in the meantime.)

## 3. Create a user flow

External ID → *User flows* → new **Sign up and sign in** flow:
- Name: `portal_signupsignin`
- Identity providers: Email with password (add social later if wanted)
- User attributes to collect: email, display name
- Application: associate the Portal SPA registration

## 4. Hand the values to Phase 2

Give these to the Phase 2 wiring (they become Terraform `tfvars` /
GitHub Actions variables — none are secrets except where noted):

| Value | Where it came from |
|---|---|
| External ID tenant ID | step 1 |
| External ID primary domain | step 1 |
| Portal SPA client ID | step 2a |
| Portal API client ID / App ID URI | step 2b |
| User flow name | step 3 |

## 5. First users (Phase 5)

When onboarding the first client, their approver self-signs-up via the
flow (or is invited), then gets a `users` doc with
`role = client_approver` and their `clientId`. Alex gets `role = admin`
+ `contractor`. Role assignment is data in the `users` container, not an
Entra construct — so adding a client approver never touches the
directory config.
