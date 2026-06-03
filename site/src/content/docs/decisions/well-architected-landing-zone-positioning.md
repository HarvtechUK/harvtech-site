---
title: Positioning — well-architected Azure landing zones
description: Walking back the generic-cloud framing in favour of a specific Azure landing-zone narrative, with AI as one of several modern workloads.
category: decisions
order: 25
updated: 2026-06-03
status: living
---

## Context

The earlier hero positioning — *"Secure Cloud platforms for AI and data workloads"* — was deliberately
generic about the cloud and led on AI. Both choices made sense at the time and are documented in
[the previous ADR](/docs/decisions/cloud-not-azure-in-heading), which this one supersedes.

Two things shifted the thinking:

- **Generic "Cloud" reads as soup-of-the-day SaaS.** It avoids filtering out AWS/GCP conversations,
  but it also doesn't earn a second look. "Secure Azure landing zone" is a concrete CAF concept that
  signals real depth of platform knowledge — a more honest signal of what I actually do day-to-day.
- **AI in the headline narrows the room.** AI is a workload, not a discipline. Leading with it pushes
  away clients who want a well-architected platform for *their* workload — data, web, line-of-business,
  identity-heavy, whatever. The platform skills don't change.

Same code in this repo. Same skills. Different framing.

## Decision

- **Hero headline:** *"Well-architected Azure landing zones."*
- **Hero body:** opens with "Secure foundations for modern workloads — including AI, data, and
  everything in between" before listing the day-job stack.
- **Meta description, footer, page titles:** all rewritten around "well-architected Azure landing
  zones — secure foundations for modern workloads".
- **Showcase in-progress card** renamed from *"Secure AI Landing Zone"* to *"Reference Azure landing
  zone"*. AI (Azure OpenAI / Foundry) is described as *one demonstrated workload on top*, alongside
  data and app-tier examples — not the headline.
- **Writing page** description and intro broaden from "AI workload security" to "modern-workload
  security (AI included)".

## What stays as it was

- Capability cards (Cloud platform engineering, Terraform at scale, DevSecOps in CI/CD, etc.) were
  already generic — no changes needed.
- The CV stays Azure-led with AWS/GCP as background; that was already accurate.
- The data platform HLD still describes AI as a workload it could feed, where that's factually true.
  The reframe is about *headline positioning*, not about scrubbing every accurate mention.

## Consequences

- **Pro:** specific framing earns trust. "Well-architected Azure landing zone" is a concept a CTO or
  platform lead recognises in three seconds.
- **Pro:** broader workload appeal. Anyone shipping anything serious on Azure benefits from the same
  foundations; the AI angle becomes a demonstrated example rather than a gate.
- **Con:** loses the deliberate "Cloud not Azure" hedging from the earlier ADR. The cross-cloud
  background is still in the body and CV, so the cost is small — a non-Azure prospect has to read
  one more sentence rather than bouncing on the headline.
- **Con:** one ADR walking back another adds wiki noise. Kept the old ADR live and marked it
  superseded so the trade-off thinking is visible, rather than rewriting history.

## Alternatives considered

- **Keep the generic "Cloud" framing.** Rejected — too vague to differentiate, and the AI-headline
  side of the old framing was always the weaker half.
- **Lead with the AI specialism instead.** Rejected for the workload-narrowing reason above. AI work
  remains in the showcase and writing, just not the headline.
- **Drop AI from the site entirely.** Rejected — securing AI workloads (private endpoints around
  Foundry, identity around the model surface, WAF in front of the app tier) is genuinely interesting
  work and a credible portfolio piece, just not the lead claim.

## Implementation

Single PR refactoring the hero, footer, meta description, showcase in-progress card, and writing
page copy. Old ADR marked `status: superseded` with a forward link to this one. No code or
Terraform changes — this is positioning, not architecture.
