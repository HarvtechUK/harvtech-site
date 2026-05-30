# harvtech-site

Source for [HarvTech.co.uk](https://harvtech.co.uk) — a portfolio site showcasing secure Azure platform engineering for AI and data workloads.

## Architecture

- Static site (placeholder HTML now, Astro later) hosted on Azure Storage `$web`
- Infrastructure as code: Terraform, state in Azure Storage backend
- CI/CD: GitHub Actions, federated to Azure via OIDC (no stored secrets)
- Coming next: Azure Front Door + WAF, custom domain, Astro build pipeline

## Repo layout

| Path | Purpose | State key |
|------|---------|-----------|
| `bootstrap/` | One-off shell script + docs for the manually-managed platform layer (state SA, Entra app, federated creds) | — |
| `infra/` | Terraform for the site's Azure resources (RG, storage, Front Door, WAF) | `site.tfstate` |
| `dns/` | Terraform for the `harvtech.co.uk` DNS zone + records | `dns.tfstate` |
| `site/` | Static site content (currently placeholder HTML) | — |
| `.github/workflows/` | CI/CD pipeline | — |

All Terraform state lives in `stplatformtfstateuks01` (`rg-platform-prd-uks-01`).
Application stacks consume the platform layer; the platform layer itself is
maintained out of band — see [`bootstrap/README.md`](bootstrap/README.md).

## Pipeline security

Two workflows run on every push, PR, and daily on a schedule:

- **`deploy.yml`** — `terraform plan/apply` for both stacks, then upload site content
- **`security.yml`** — three scanners running in parallel, all emitting SARIF into the [Security tab](https://github.com/HarvtechUK/harvtech-site/security/code-scanning):
  - **Checkov** — IaC policy and misconfiguration
  - **Trivy** — IaC misconfig from a different ruleset (deliberate overlap with Checkov; disagreements between them tend to surface findings worth investigating)
  - **tflint** + `tflint-ruleset-azurerm` — Terraform linting, dead-code detection, Azure SKU validation

All three start in soft-fail mode so we get visibility on what's there before we decide what to enforce. Deliberate suppressions live in `.checkov.yaml` / `.tflint.hcl` with a one-line reason for each, so the trade-offs are reviewable.

Dependabot watches GitHub Actions versions and Terraform providers/modules weekly (`/.github/dependabot.yml`).

## Deploy

Pushes to `main` run `terraform apply` and upload `site/` to the storage account.
