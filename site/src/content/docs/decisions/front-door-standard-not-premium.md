---
title: Front Door Standard, not Premium
description: Why we chose Standard SKU even though Premium would close a Critical security finding.
category: decisions
order: 10
updated: 2026-05-30
status: living
---

## Context

This site is served via Azure Front Door. Two SKUs exist: Standard and Premium. Standard is ~£25/month base; Premium is ~£200/month base.

## Decision

Standard.

## Consequences

What we lose by being on Standard:

- **No managed WAF rulesets** — Microsoft DRS and Bot Manager are Premium-only. We compensate with custom WAF rules that block the actual attack patterns we see (WordPress probes, PHP scans, dotfile/VCS probes, admin-panel discovery) plus a 100 req/min per-IP rate limit. Detail in `infra/waf.tf`.
- **No Private Link to origin** — Premium can use real Private Link from FD to the storage backend; Standard can't. Without that, locking the storage account to only-FD-can-reach isn't possible (the resource-instance-rule feature explicitly doesn't list `Microsoft.Cdn/profiles` as a supported source). Trivy AZU-0012 (default network action should be deny) is therefore suppressed-with-reasoning rather than fixed in code. The bypass path — direct access to `*.web.core.windows.net` — exists in theory; in practice it serves the same static HTML as the FD path, just without WAF interposition.

What Standard does give us:

- WAF custom rules and rate limiting (sufficient for a static portfolio site)
- Managed TLS certificates for the custom domains
- HTTPS-only routing with HTTP→HTTPS redirect
- Custom rules engine (used for `www` → apex 301)
- The same global anycast network as Premium

## Alternatives considered

- **Premium FD** — ~£200/month uplift. Buys us the items above. Not justified for a personal portfolio; would be the right call for a client engagement where the WAF managed ruleset alone moves the risk needle.
- **A different origin altogether** — App Service, Static Web Apps, AKS. Each would be in the supported list for storage resource-instance rules or have its own equivalent. But we'd lose the static-HTML simplicity of Storage `$web` and pick up other compute costs.

## Trigger for reconsideration

- If we add an interactive component (e.g. a contact form or an AI gimmick) that actually merits real WAF managed rules and request inspection
- If we ever serve content that genuinely requires the origin to be unreachable from the public internet
- If the personal site's traffic profile changes such that DDoS protection becomes a real concern rather than a theoretical one
