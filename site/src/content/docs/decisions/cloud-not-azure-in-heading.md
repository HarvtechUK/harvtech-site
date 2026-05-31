---
title: '"Cloud" not "Azure" in the headline'
description: Why the public-facing positioning is deliberately broader than the day-job stack.
category: decisions
order: 30
updated: 2026-05-30
status: living
---

## Context

The hero headline originally read **"Secure Azure platforms for AI and data workloads."** That's accurate to the day-job stack but reads as a filter that excludes AWS- and GCP-shaped engagements.

A potential client searching for "secure cloud contractor with infrastructure as code experience" might bounce off a site that brands itself as Azure-only, even if the underlying skills transfer cleanly to other clouds.

## Decision

- Hero headline now reads **"Secure Cloud platforms for AI and data workloads."**
- Capability card title broadened from "Azure platform engineering" to "Cloud platform engineering"
- Section heading "Platform and security work for teams shipping into Azure." → "...to the cloud."
- The hero body and CV explicitly mention Microsoft Azure as the primary stack and AWS/GCP as background — accurate without being misleading.

## What stays Azure-specific

Where the text is **factual experience-stating**, Azure stays:

- Hero body: "the last seven years focused on Microsoft Azure" — accurate
- Specific tech in capability cards: Front Door + WAF, Entra ID, Defender for Cloud, OIDC federation to Azure
- Footer attribution: "Hosted on Azure" (because it literally is)
- ADRs and docs reference specific Azure services by name (because they're talking about specific systems)

Generic positioning ("we do X for teams shipping to the cloud") gets the broader framing. Specific claims ("I've spent seven years on Azure") stay precise.

## Consequences

- Doesn't forclose on AWS or GCP conversations
- Doesn't pretend to be cloud-agnostic in a way that would fall apart in a technical interview
- Slightly more text on the page because the differentiation between "primary stack" and "broader skill set" needs spelling out
- A casual reader sees "cloud platform engineering" and then meaningful Azure-specific detail underneath — which models the right thing (broad framing, specific evidence)

## Alternatives considered

- **Keep "Azure" in the headline** — would be more authentic to actual day-job experience. Rejected because the cost of filtering out non-Azure conversations exceeds the cost of being briefly explicit about specialism vs background.
- **Pretend to be cloud-agnostic** — would invite questions in interviews that don't have honest answers. Rejected.
- **No specific cloud in headline at all** — too generic. "Secure platforms for AI and data workloads" reads as soup-of-the-day SaaS.
