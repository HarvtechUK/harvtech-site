---
title: Platform RG separated from application resources
description: Why Terraform state and shared identity live in their own resource group rather than alongside the site.
category: decisions
order: 20
updated: 2026-05-29
status: living
---

## Context

Terraform needs somewhere to store remote state. The first commit on this repo created that storage account in a resource group called `rg-harvtech-bootstrap-uks` — a name that implicitly tied it to this one project.

That was wrong for two reasons:

1. **It baked "harvtech" into a layer that should be project-agnostic** — future projects in the same subscription would want to share the same state backend without inheriting harvtech's name.
2. **It conflated platform and application access boundaries** — a developer working on application code shouldn't need (or have) access to the state storage account that contains every project's secrets-in-state.

## Decision

Move state storage into a separately-scoped platform resource group, named in the standard Azure CAF convention: `rg-platform-prd-uks-01`. State storage account became `stplatformtfstateuks01`. Anything else that's truly "shared infrastructure consumed by many projects" goes here too.

## Consequences

- **RBAC story is cleaner** — the platform RG can have restrictive RBAC (only SREs / specific SPs that need state-write), while project RGs (e.g. `rg-harvtech-site-prod-uks`) can have broader access for application developers without that bleeding through to platform resources.
- **Future projects fit the pattern** — a new project's CI just needs Storage Blob Data Contributor on the existing platform state SA. No new platform infra per project.
- **The migration itself was non-trivial** — see the git history around commit `5480d3a`. The state blobs were server-side copied with `az storage blob copy start --requires-sync`, verified MD5-identical, then `backend.tf` repointed in both stacks and `terraform init -reconfigure` showed zero drift.

## Alternatives considered

- **Leave it in the bootstrap RG** — works, but didn't model the right access boundary and would invite the same problem again when a second project lands.
- **One RG per environment, not per layer** — e.g. `rg-harvtech-prd-uks` containing both site infra and state. Easier short-term, but couples platform and application lifecycles in a way that doesn't reflect how the access permissions should differ.
- **Different name** — "shared", "hub", "landingzone" were all considered. "Platform" matches the Cloud Adoption Framework's terminology for foundational shared services and reads correctly to a hiring manager auditing the repo.

## Note on the chicken-and-egg

The platform RG can't be Terraform-managed by Terraform that uses it. That's documented out of band in `bootstrap/README.md` and `bootstrap/bootstrap.sh` — the manual setup script that creates the RG, the state SA, the container, the Entra app, the federated credentials, and the baseline RBAC. Designed to be read more than executed, but idempotent enough to re-run if rebuilding from scratch in a fresh subscription.
