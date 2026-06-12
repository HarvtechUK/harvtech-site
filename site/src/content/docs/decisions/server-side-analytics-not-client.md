---
title: Server-side analytics, not a client-side tracker
description: Why visitor analytics come from Front Door logs in Log Analytics rather than a JavaScript snippet.
category: decisions
order: 50
updated: 2026-06-12
status: living
---

## Context

The site had no visitor analytics at all, and the privacy policy promised "no tracking cookies, no third-party analytics, no browsing data collected". Three options were on the table:

1. **Hosted cookieless analytics** (Plausible ~€9/month, Fathom ~$15/month) — privacy-friendly, but a recurring cost and a third-party data processor to name in the privacy policy.
2. **Self-hosted umami on Azure** — more IaC to show off, but ~£13–18/month (Postgres Flexible Server + Container Apps), a client-side script, and an always-on service to patch and back up.
3. **Azure Front Door access logs → Log Analytics** — server-side only, zero client JavaScript, queryable with KQL.

## Decision

Option 3. Front Door already sees every request at the edge; a diagnostic setting ships its access and WAF logs to a Log Analytics workspace, and saved KQL searches provide the reports (page views, unique visitors, top pages, referrers, WAF blocks). Implementation in `infra/observability.tf`.

Unique visitors are approximated as `dcount(client IP + user agent)` — the same cookieless technique the hosted providers use, minus the script tag.

## Consequences

- **Cost is pennies.** The workspace SKU (PerGB2018) has no base charge; this site's logs are tens of MB/month against ~£2.30/GB ingestion, with 31 days' retention included. A 1 GB/day cap bounds a log-flood at ~£2.30/day.
- **No consent banner, no client JS.** Nothing runs in the visitor's browser. The privacy policy describes the server-side logs (IP, path, referrer, user agent, 30-day retention) under legitimate interests — server logs still contain personal data (IP addresses), so "we collect nothing" would have been false; the policy says what's actually collected and why.
- **Closed two deferred scanner findings.** The same workspace takes blob-service diagnostics from the `$web` origin, which is what Checkov CKV2_AZURE_21 (blob read logging) asked for. Trivy AZU-0057 stays suppressed but the reasoning changed from "deferred" to "the check only recognises legacy Storage Analytics `queue_properties` logging, not diagnostic settings".
- **The numbers are honest approximations, not product analytics.** Bots that lie about their user agent are counted; cached-at-browser repeat views aren't; there's no scroll depth or session replay. For "is anyone reading this, and from where?", that's enough.

## Alternatives considered

- **Plausible / Fathom** — the right call when someone non-technical needs a dashboard, or when marketing wants campaign attribution. Neither applies here, and £80–140/year buys nothing this setup doesn't already do.
- **Self-hosted umami** — tempting as a showcase piece, but it showcases the wrong thing: running a stateful web app to count visits to a static site inverts the cost/complexity story the rest of this project tells. The Front Door route demonstrates the more transferable skill (Azure-native observability + KQL).
- **Application Insights with the JS SDK** — real client-side telemetry, but it sets cookies by default, which means a consent banner and a much longer privacy policy for marginal gain on a content site.

## Trigger for reconsideration

- A client-facing reason to measure in-page behaviour (scroll, interactions, funnels) rather than requests.
- Front Door pricing or Log Analytics ingestion changes that break the "pennies" assumption.
- Needing to share a live analytics dashboard with someone who shouldn't have workspace reader access — at that point a hosted tool's shareable dashboards earn their fee.
