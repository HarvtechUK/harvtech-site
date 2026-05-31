---
title: Snyk IaC dropped, Snyk Open Source kept
description: Why the pipeline runs Snyk for npm dependency CVEs but not for Terraform misconfig.
category: decisions
order: 40
updated: 2026-05-31
status: living
---

## Context

The pipeline already had three IaC scanners: Checkov, Trivy, and tflint. Snyk was added on top of that with two scopes:

- **Snyk Open Source** — npm dependency CVE scanning on `site/package-lock.json`. New capability nothing else in the pipeline covered.
- **Snyk IaC** — Terraform misconfig scanning. Heavy overlap with Checkov and Trivy by design — three scanners with overlapping rules surfaces genuine findings as the ones they disagree on.

First run found exactly what the others did: one Medium severity finding, `SNYK-CC-AZURE-649` (Storage Account geo-replication disabled). Same rule, same conclusion as Checkov `CKV_AZURE_206` and Trivy `AZU-0058`.

## The wall we hit

The other three scanners all support in-git suppression with a documented reason:

- Checkov reads `.checkov.yaml` and its `skip-check:` list
- Trivy reads `.trivyignore`
- tflint reads `.tflint.hcl` for rule disables

Snyk Open Source supports the same pattern via `.snyk` — works perfectly.

**Snyk IaC's current CLI scanner (v2, default since 2023) does not honour `.snyk` ignores.** Ignores have to be configured in the Snyk Web UI after running with `--report`, which then syncs them back to subsequent scans.

This was tried with multiple combinations:

- `.snyk` at repo root with `'*'` as the path key — ignored
- `.snyk` at repo root with the exact resource-path string Snyk itself prints — ignored
- Explicit `--policy-path=.snyk` flag in the workflow — same result

Snyk's docs on this aren't crisp (the relevant pages 404), but the behaviour is consistent and documented in community threads: v2 IaC has moved ignore management out of the policy file and into the Snyk Cloud UI.

## Decision

Drop Snyk IaC from the pipeline. Keep Snyk Open Source.

## Why

Two reasons together:

1. **Pattern matters more than coverage.** Having one scanner manage its config in a SaaS UI while the others are in git breaks the auditability story. Future contributors trying to understand "what's being suppressed and why" would have to know to also check the Snyk Web UI. That's an invitation for drift.

2. **The overlap wasn't earning it.** Snyk IaC's findings were a subset of what Checkov + Trivy already flagged. Three overlapping IaC scanners would be defensible if at least one was finding something the others missed; in practice Snyk's first run found a single rule that two other scanners already had suppressions for. The marginal benefit didn't justify the broken pattern.

Snyk Open Source stays for a different reason: it covers a dimension nothing else in the pipeline does (known CVEs in the npm dependency tree). Dependabot does version-bump PRs but doesn't actively scan for vulns; Snyk Open Source does. First run was clean ("335 dependencies tested, no vulnerable paths found"), and when there is something to suppress, `.snyk` works correctly for the Open Source scanner.

## Consequences

- **Pipeline configuration**: `security.yml` has the `snyk-iac` job removed and the `.snyk` file deleted (was only there for the IaC ignore that didn't work).
- **Required CI checks**: `Snyk (Open Source)` added to branch protection. Now 8 required checks.
- **Cleanup**: The orphaned `snyk-iac` Code Scanning alert from the initial integration run was dismissed via the GitHub API with `dismissed_reason: "won't fix"` and a comment pointing back to this ADR.
- **What we lose**: a third opinion on Terraform misconfig findings. In practice, Checkov + Trivy already produce more findings than we have time to investigate, and the union of their rulesets is comprehensive.
- **What we keep**: npm CVE scanning that's genuinely net new, and an integration pattern in git that matches the other scanners.

## Trigger for reconsideration

- Snyk fixes IaC ignore handling in the CLI such that `.snyk` works the same way it does for Open Source. (Snyk releases happen often; worth checking once a year.)
- The pipeline gains content that Snyk IaC's ruleset specifically would catch and Checkov + Trivy wouldn't. Their rule libraries evolve, so this isn't impossible.
- The project grows to a scale where a Snyk Cloud-managed posture is worth integrating with for unified visibility across multiple projects. Not the current situation.

## Postscript on tool selection

For a portfolio repo this whole sequence — added a tool, hit a real limitation, made a principled call to scope it down rather than ignore the problem — is more valuable than blindly stacking scanners. Hiring managers care more about engineering judgement than tool count. Future scanner additions should pass the same test: does it add a dimension nothing else covers, AND can its config live in git alongside everything else?
