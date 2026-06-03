---
title: Site infrastructure HLD
description: How harvtech.co.uk fits together end to end — platform layer, application stacks, edge, identity, CI/CD.
category: architecture
order: 10
updated: 2026-05-31
status: living
---

This page documents the architecture of the site you're reading. The repo is public at [github.com/HarvtechUK/harvtech-site](https://github.com/HarvtechUK/harvtech-site); the source for this doc itself is in `site/src/content/docs/architecture/site-infra-hld.md`.

## Goals

1. **Be a credible portfolio artifact** — the site has to be the work, not a description of the work. Every architectural decision should be auditable from the repo.
2. **Honest about trade-offs** — Standard SKU vs Premium, accepted-with-reasoning security findings, the SP RBAC tape-fix waiting for a follow-up. The wins and the deferred items both belong on the page.
3. **Cheap to run** — personal Azure subscription, ~£30/month all-in including Front Door Standard. No paid-tier services that aren't earning their keep.
4. **Production-grade by example** — IaC from the first commit, OIDC-federated CI/CD, branch protection, IaC scanning, real secrets discipline. The shape of the system should resemble what a small team would actually build for a client.

## Component map

The system lives in three logical layers:

| Layer | What it contains | Managed how |
| --- | --- | --- |
| **Platform** | The Terraform state storage account, the Entra app and federated credentials used by CI, baseline RBAC | Manually via `bootstrap/bootstrap.sh` — the chicken-and-egg layer that Terraform can't manage itself |
| **Application** | Site storage, Front Door + WAF, DNS records, anything that hosts or routes the content | Terraform across two stacks (`infra/` and `dns/`) |
| **Content** | The Astro source for the pages you're reading | Built in CI, uploaded as the deploy step |

The split exists so application-layer changes can move fast through PRs without touching the high-privilege platform resources. Platform changes are rare and deliberate.

## Identity and access

- **Personal admin login**: `alex@alexander-harvey.com`, Owner on the subscription. MFA enforced via Microsoft 365 Business Premium (Entra ID P1).
- **CI service principal**: `sp-github-harvtech-site` (client ID stored as a GitHub repo variable, not a secret — the ID itself isn't sensitive and Variables can be read by Dependabot PRs). Federated via OIDC to two subjects: `refs/heads/main` for push, `pull_request` for PRs. No client secret, no PAT.
- **SP roles**: Contributor at subscription scope today, Storage Blob Data Contributor on the state SA, Storage Blob Data Contributor on the site SA. Tightening this to RG-scoped is on the followup list — getting User Access Administrator on a single RG so the SP can manage its own role assignments via Terraform is the unlock.

## Application stacks

Two Terraform stacks in the repo, each with its own state blob.

### `infra/` — state key `site.tfstate`

- `rg-harvtech-site-prod-uks`
- Storage account `stharvtechsiteproduks01` with `static_website` hosting and TLS 1.2 minimum
- Front Door Standard profile with one endpoint, one origin group, one origin pointing at the storage `$web` endpoint
- Two custom domains: apex `harvtech.co.uk` and `www.harvtech.co.uk`, both Front Door managed certs
- Rules engine that 301-redirects `www` to apex
- WAF policy with custom rules covering WordPress probes, dotfile probes, admin-panel probes, and a 100 req/min rate limit per IP. No managed ruleset — Standard SKU doesn't support it, documented inline.

### `dns/` — state key `dns.tfstate`

- References the shared `rg-dns-prd-uks-01` via data source (not managed; the RG holds two unrelated zones for other projects)
- Manages the `harvtech.co.uk` zone resource itself, imported via Terraform 1.5+ `import` blocks
- M365 mail records (MX → Exchange Online, SPF TXT, autodiscover CNAME) — imported from prior manual setup
- Front Door records: apex A-alias (using Azure DNS's `target_resource_id` since CNAMEs can't sit at apex), `www` CNAME, and two `_dnsauth` TXT records populated from the infra stack's outputs via a `terraform_remote_state` data source

The cross-stack reference is why `terraform-dns` `needs: terraform-site` in the workflow — DNS reads FD's computed validation tokens, which only exist after `infra/` applies.

## Edge and content

```
Browser
  ↓ DNS resolves to FD anycast IP (Azure-managed)
Front Door (Standard)
  ↓ WAF inspects every request; blocks WordPress/PHP/admin probes; rate-limits at 100/min/IP
  ↓ www.harvtech.co.uk → 301 → apex via rules engine
  ↓ HTTPS-only, HTTP→HTTPS redirect
  ↓ TLS terminated with FD-managed cert
Storage Account ($web)
  ↓ Serves index.html for the requested path
```

Storage is publicly accessible by design — the static-website endpoint *is* the public-facing artifact for FD to fetch from. Restricting it to only-FD via resource-instance rules isn't possible on Standard SKU because `Microsoft.Cdn/profiles` isn't in Microsoft's supported resource type list for that feature ([reference](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-trusted-azure-services)). Premium FD with Private Link would solve it at ~£200/month uplift; not justified for a personal portfolio. Accepted-with-reasoning in `.trivyignore`.

## CI/CD

GitHub Actions, two workflows.

### `deploy.yml`

Three jobs:

- **terraform-site** — checkout, setup-terraform, OIDC login to Azure, `terraform init && fmt && validate && plan`. On push to main, also `apply` and capture outputs.
- **terraform-dns** — same shape, depends on `terraform-site` (cross-stack remote state read).
- **build-site** — Node 22 setup, `npm ci`, `npm run build` in `site/`. Uploads `site/dist` as an artifact. Runs on every push and PR so the build is verified before merge.
- **deploy-site** — depends on `terraform-site` and `build-site`. On push to main only: downloads the artifact and `az storage blob upload-batch` into `$web`.

### `security.yml`

Three scanners in parallel, all emitting SARIF into GitHub Code Scanning:

- **Checkov** — Palo Alto Prisma's IaC policy scanner
- **Trivy** — Aqua's IaC misconfig scanner (different ruleset to Checkov; overlap is intentional — disagreements between them are the interesting findings)
- **tflint** — Terraform linting + the `tflint-ruleset-azurerm` plugin for SKU validation and dead-code detection. Matrix over `infra` and `dns`.

Runs on push, PR, and a daily schedule (catches new rules and CVEs without needing a push).

## Branch protection

- All changes to `main` go through a PR
- Required status checks: `Terraform site`, `Terraform DNS`, `Build site`, `Checkov (IaC policy)`, `Trivy (IaC misconfig)`, `tflint (infra)`, `tflint (dns)` — 7 checks must be green
- Strict mode: PR branch must be up to date with `main` before merge
- Linear history — squash or rebase merge only, no merge commits
- Force push to `main` is blocked outright (admins can't bypass without temporarily relaxing the rule, which is itself logged in the audit trail)
- `enforce_admins = false` for the PR rule specifically, so emergency direct pushes are possible if needed, but they get flagged in the audit log

CODEOWNERS at `.github/CODEOWNERS` claims `@HarvtechUK` for the whole repo. Auto-merge is enabled at the repo level so Dependabot PRs and any human PR with `gh pr merge --auto` land as soon as CI is green.

## Site source (`site/`)

- Astro 6 + Tailwind 4 + TypeScript
- Pinned to Astro `~6.1.x` and Vite `~7.3.x` via overrides, because [withastro/astro#16542](https://github.com/withastro/astro/issues/16542) — Astro 6.2+ defaults to rolldown-vite which currently breaks `@tailwindcss/vite`. Revisit when upstream lands a fix.
- Theme tokens modelled on [Tailcast (MIT)](https://github.com/matt765/Tailcast), credited inline in `site/src/styles/theme.css` and in the footer
- Inter via `@fontsource/inter` — Latin subsets only, saves ~600 KB of bandwidth per page load over the all-subsets default
- Built output is ~312 KB total, fonts dominant

## Trade-offs documented elsewhere

For the bigger decisions, see the `decisions/` category — each ADR captures the choice, the alternatives considered, and the reasoning. The deferred items (SA modernisation, SP RBAC tightening, Diagnostic Settings to Log Analytics) live as TODO notes in the relevant Terraform files and in the project memory.

## What's not here yet

- Diagrams — this doc is text-only for v1. Adding Mermaid via remark plugin is a follow-up.
- Reference Azure landing zone lab — planned as a separate repo, with this site hosting its case study and writeup. AI (Azure OpenAI / Foundry) drops in as one demonstrated workload on top, alongside data and app-tier examples.
- Diagnostic Settings to a Log Analytics workspace — closes two Checkov/Trivy suppressions (storage logging and queue logging) when it lands.
- `infrastructure_encryption_enabled = true` on the storage account — requires SA replacement, currently bundled with the SP RBAC modernisation work for safe coordination.
