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
| `infra/` | Terraform for the site's Azure resources | `site.tfstate` |
| `dns/` | Terraform for the `harvtech.co.uk` DNS zone | `dns.tfstate` |
| `site/` | Static site content (currently placeholder HTML) | — |
| `.github/workflows/` | CI/CD pipeline | — |

## Deploy

Pushes to `main` run `terraform apply` and upload `site/` to the storage account.
