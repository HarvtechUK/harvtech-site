---
title: Lock down a personal Azure + GitHub admin account
description: Step-by-step runbook for MFA, Conditional Access, and break-glass on a one-admin Entra tenant plus its GitHub counterpart.
category: how-to
order: 10
updated: 2026-05-31
status: draft
---

> **Status: draft.** Being written as the work happens. Final version will cover the full sequence end-to-end, including the Terraform-managed Conditional Access stack and break-glass account.

## Why bother

If the admin login is a one-password compromise away from full takeover, every other security control on the platform is theatre. This applies whether you're a solo developer with one Owner account on a personal subscription, or an SRE with Global Admin in a client tenant — the playbook is the same, just the policies tighten over time.

## What "locked down" looks like

| Layer | Minimum acceptable | What we're aiming for |
| --- | --- | --- |
| Authentication factor | Authenticator app (TOTP) | Phishing-resistant: passkey or FIDO2 |
| Coverage | Some sign-ins challenge for MFA | Every sign-in challenges; no fallback to password-only |
| Audit trail | Sign-in logs retained | Logs retained AND reviewed; anomalies investigated |
| Disaster recovery | Recovery codes saved | Break-glass account with separate MFA, never used day-to-day |
| Change management | Settings tweaked in the portal | Settings codified as Terraform; portal drift is detectable |

## Sequence

### 1. Register MFA methods (no enforcement yet)

To be documented.

### 2. Confirm enforcement state

To be documented.

### 3. Move from Security Defaults to Conditional Access

To be documented.

### 4. Create a break-glass account

To be documented.

### 5. Codify the Conditional Access policies in Terraform

To be documented.

### 6. Same playbook for GitHub

To be documented.

## What goes wrong

To be documented.
