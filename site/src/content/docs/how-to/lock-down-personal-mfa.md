---
title: Lock down a personal Azure + GitHub admin account
description: Step-by-step runbook for taking a solo developer's Entra and GitHub identities from password-only to phishing-resistant MFA in under an hour.
category: how-to
order: 10
updated: 2026-05-31
status: living
---

## Why bother

If the admin login is a one-password compromise away from full takeover, every other security control on the platform is theatre. This applies whether you're a solo developer with one Owner account on a personal subscription, or an SRE with Global Admin in a client tenant — the playbook is the same, just the policies tighten over time.

The work below is what was actually run through on this account on 2026-05-31, starting from password-only and ending with phishing-resistant MFA enforced tenant-wide.

## What "locked down" looks like

| Layer | Minimum acceptable | What we're aiming for |
| --- | --- | --- |
| Authentication factor | Authenticator app TOTP | Phishing-resistant: passkey or FIDO2 |
| Coverage | MFA challenge on some sign-ins | Every sign-in challenges; no fallback to password-only |
| Tenant policy | Security Defaults enabled | Conditional Access policies (codified in Terraform) |
| Audit trail | Sign-in logs retained | Logs retained AND reviewed; anomalies investigated |
| Disaster recovery | Recovery codes saved | Break-glass account with separate MFA, never used day-to-day |
| Change management | Settings tweaked in the portal | Settings codified as Terraform; portal drift is detectable |

The "minimum acceptable" column is what landed today. The "aiming for" column captures what's still to do (see [What's still TODO](#whats-still-todo)).

## Where we started

Baseline check via `az` and `gh` CLIs:

```bash
# Azure identity + role
az account show --query "{user: user.name, tenantId: tenantId}" -o json
az role assignment list --assignee "$(az ad signed-in-user show --query id -o tsv)"

# Tenant licences (tells you what Entra SKUs you have)
az rest --method GET --url "https://graph.microsoft.com/v1.0/subscribedSkus" \
  --query "value[].{skuPartNumber: skuPartNumber}" -o json

# Conditional Access policies (empty list = none defined)
az rest --method GET --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" \
  --query "value[].{displayName: displayName, state: state}" -o json

# GitHub: 2FA state, SSH keys, repo security features
gh api user --jq '{login, two_factor_authentication, plan: .plan.name}'
gh api user/keys --jq '.[] | {id, title}'
gh api repos/HarvtechUK/harvtech-site --jq '.security_and_analysis'
```

Findings:

- **Azure identity**: Owner on the subscription via `alex@alexander-harvey.com`. Tenant has Microsoft 365 Business Premium, which includes **Entra ID P1** — Conditional Access available.
- **No Conditional Access policies** existed.
- **Microsoft Authenticator was registered** (Alex had set it up previously and forgotten — common pattern).
- **Security Defaults state** couldn't be queried via CLI without elevated permissions; required a portal check.
- **GitHub 2FA was OFF**, even though a passkey was registered as a sign-in method. Critical distinction — see below.

## Step 1 — Confirm Entra MFA registration

If `mysignins.microsoft.com/security-info` already lists Microsoft Authenticator (or any strong factor), this step is done.

If not:

1. Install **Microsoft Authenticator** on phone
2. Open `https://mysignins.microsoft.com/security-info` in a private browser window
3. Sign in
4. **+ Add sign-in method** → **Authenticator app** → scan the QR code in the phone app
5. Approve the test notification
6. Set as the default sign-in method
7. Don't add SMS as a fallback — it's phishable via SIM-swap

## Step 2 — Check Security Defaults state

Security Defaults is the tenant-wide "everyone gets MFA, legacy auth blocked" toggle. It's the free baseline that catches the basics.

1. `https://entra.microsoft.com/`
2. Left nav: **Identity** → **Overview** → top tab **Properties**
3. Scroll to **Manage security defaults**
4. Read the toggle: **Enabled** or **Disabled**

If **Disabled**: enable it now. This forces MFA registration for all users within 14 days and immediately blocks legacy auth.

If **Enabled**: you're already covered for the immediate threat. Plan the upgrade to Conditional Access (see [TODO](#whats-still-todo)) as a follow-up — CA is more granular and is Terraform-manageable. **Note**: Security Defaults and Conditional Access cannot coexist. The CA migration will disable SD first.

## Step 3 — Enable GitHub 2FA properly

This is the one that catches people. **Having a passkey as a "sign-in method" on GitHub is NOT the same as having 2FA enabled.**

- Passkey-as-sign-in: GitHub allows you to *additionally* sign in with passkey. The password flow still exists alongside.
- 2FA enabled: every sign-in path, including password, requires a second factor.

If 2FA is "Not enabled" in `github.com/settings/security`, the account is still vulnerable to a stolen password + email takeover sequence.

To enable:

1. `https://github.com/settings/security`
2. **Two-factor authentication** section → **Enable two-factor authentication**
3. Pick **Set up using an app** (TOTP / Authenticator). Reuse the same Microsoft Authenticator app — it supports multiple accounts.
4. Scan the QR, enter the code
5. **Save recovery codes** — copy them and put them in your password manager. Single-use; if your phone is lost AND your passkey isn't accessible, these are the only way back in.
6. After 2FA is on, the passkey continues to work for passwordless sign-in too — best of both: one-tap auth, but every path is gated.
7. Do **not** enable SMS as a fallback.

Verifying via API doesn't reliably work for OAuth tokens — the `two_factor_authentication` field on `gh api user` returns `null` for OAuth scopes that don't include `read:user`. The UI is the authoritative answer.

## Step 4 — Add phishing-resistant MFA (passkey)

Authenticator TOTP is good but it's **phishable** by real-time relay phishing kits (Evilginx, Modlishka, off-the-shelf and cheap). The attacker mirrors the Microsoft login page on a lookalike domain, captures both your password and the 6-digit code, replays them to Microsoft within seconds, captures the resulting session cookie. Your MFA didn't help.

**Passkey or FIDO2 security key** is cryptographically bound to the actual domain. A relay phishing kit can't satisfy the challenge because the credential won't sign for `microsoft-signin.fake.com` — only for the real `login.microsoftonline.com`.

iCloud Keychain on macOS gives this for free, no hardware key purchase needed.

### 4a. Enable Passkey/FIDO2 at the tenant level

Microsoft doesn't ship this on by default. As a tenant admin:

1. `https://entra.microsoft.com/`
2. **Protection** → **Authentication methods** → **Policies**
3. Find **Passkey (FIDO2)** (older branding: **FIDO2 security key**)
4. Click in, set **Enable** to **Yes**
5. **Include**: All users (or scope tighter to specific people)
6. Defaults under **Configure** are fine for personal use
7. Save

### 4b. Register the passkey

1. `https://mysignins.microsoft.com/security-info` (Safari works best for iCloud Keychain integration on Mac)
2. **+ Add sign-in method** → **Passkey** (or **Security key** depending on UI version)
3. Choose **iCloud Keychain** / **Use this device**
4. Touch ID / Face ID / Mac password authorises the passkey
5. Done. Next sign-in: tap to use passkey, one factor for the whole flow.

## What's still TODO

Things deferred to a future session, captured for the next pass:

- **Replace Security Defaults with Conditional Access policies, codified in Terraform**. The `azuread` provider has resources for CA policies. Building this as a separate `azuread/` Terraform stack means the policies are auditable in git, drift-detectable, and reviewable in PRs. Strong portfolio piece. Policies to author:
  - Require MFA for all users
  - Require **phishing-resistant** MFA for any sign-in from "Azure management" client app
  - Block legacy auth (Security Defaults already does this; CA replicates it explicitly)
  - Sign-in frequency: re-authenticate every N hours for privileged sign-ins
- **Break-glass account**: a second Global Admin, cloud-only, with its own FIDO2 key, excluded from CA policies that could lock everyone out, never used for day-to-day. Stored in safe + password manager.
- **Tighten the CI SP RBAC**: `sp-github-harvtech-site` is currently Contributor at subscription scope. Should be RG-scoped (per stack), with Storage Blob Data Contributor on specific storage accounts. Requires the SP to also have User Access Administrator on the site RG so Terraform can manage its own role assignments — chicken-and-egg, handled in the bootstrap script.
- **Review sign-in logs periodically**: `entra.microsoft.com → Monitoring → Sign-in logs`. Set up an alert rule for anomalous sign-ins (new country, impossible travel) if/when on P2.

## What goes wrong

A few traps worth flagging:

- **Locking yourself out**: never tighten enforcement (especially CA policies) without a tested break-glass account. CA policies have a "What if" tool in the portal — use it before you flip Enabled.
- **CLI token caching**: enabling MFA enforcement doesn't immediately invalidate existing `az login` or `gh auth` tokens. They'll continue working until expiry. Useful (so you don't lock yourself out of the terminal that's making these changes), but means a stolen token is still usable for ~24 hours.
- **Authenticator backup**: if you switch phones without exporting Authenticator first, you lose all the TOTP entries. Authenticator supports cloud backup — turn it on inside the app (Settings → Backup) before you ever switch devices.
- **GitHub passkey-without-2FA**: as covered in Step 3, the two concepts are independent on GitHub. Always confirm 2FA is the toggle, not just "I have a passkey registered".
