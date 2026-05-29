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

## Deploy

Pushes to `main` run `terraform apply` and upload `site/` to the storage account.
