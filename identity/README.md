# identity/

Terraform stack for Entra ID identity policy — Conditional Access policies, Named Locations, and the break-glass exclusion plumbing.

## Scope

Only CA-related resources. User accounts (other than the break-glass *data source* lookup) are not managed here; users are created out of band via the portal.

## State

- Backend: same Azure Storage backend as `infra/` and `dns/`
- State key: `identity.tfstate`

## Service principal

This stack uses a **dedicated SP** (`sp-github-harvtech-identity`), separate from the app-infra SP that `infra/` and `dns/` use. The split is deliberate:

| Concern | SP | Azure RBAC | Microsoft Graph perms |
|---|---|---|---|
| App infra (storage, FD, DNS) | `sp-github-harvtech-site` | Contributor on subscription, SBD Contributor on state SA | None |
| Identity policy (this stack) | `sp-github-harvtech-identity` | SBD Contributor on state SA only | Policy.Read.All, Policy.ReadWrite.ConditionalAccess, User.Read.All |

Compromise of either bounds the blast radius accordingly — neither SP alone can both spin up infra and weaken MFA enforcement.

## Policies

| ID | Name | What it does | Roll-out state |
|---|---|---|---|
| CA001 | Require MFA for all users | Every user, every cloud app, MFA required | Report-only initially |
| CA002 | Block legacy authentication | Rejects basic-auth POP3/IMAP/SMTP/EAS sessions | Report-only initially |
| CA003 | Admins must use phishing-resistant MFA | GA, Security Admin, Exchange Admin, etc. must use passkey / FIDO2 (no Authenticator TOTP) | Report-only initially |
| CA004 | Block sign-ins from outside allowed countries | Geo-block via Named Location | Report-only initially |
| CA005 | Admin sign-in frequency 12h | GA / Security Admin re-auth every 12 hours | Report-only initially |

**Every policy excludes the break-glass account** (`breakglass@marvtec.onmicrosoft.com`) so a misconfiguration here can't lock out the tenant.

## Roll-out

Every policy is created with `state = enabledForReportingButNotEnforced` by default. This is the Microsoft-recommended safe-rollout mode: the engine evaluates the policy against every real sign-in and logs what WOULD have happened, but doesn't enforce. Review the result in Entra → Monitoring → Sign-in logs, filter by the policy name, look for unexpected blocks.

When you're satisfied no surprises lurk, flip the policy_state variable in a follow-up commit:

```hcl
# identity/variables.tf
variable "policy_state" {
  default = "enabled"  # was "enabledForReportingButNotEnforced"
}
```

That one-line change moves all five policies from report-only to enforced. Same plan-and-apply via CI as any other change in this repo.

After that, **disable Security Defaults** in the Entra portal (Identity → Overview → Properties → Manage security defaults → Disabled). CA and Security Defaults are mutually exclusive and SD is now redundant.

## Break-glass procedure

If a CA policy misfires and locks the daily-use account out:

1. Sign in to https://portal.azure.com using `breakglass@marvtec.onmicrosoft.com`
2. The break-glass passkey is on a **separate device** from the daily-use one — find it
3. Once signed in, navigate to Entra → Protection → Conditional Access → Policies
4. Either disable the offending policy in the portal, OR set its state back to "Report-only" temporarily
5. Sign back in as `alex@alexander-harvey.com` to confirm
6. Open a `git revert` PR to undo the Terraform change that caused the issue
7. Sign out of break-glass; **never** let it stay signed-in

The break-glass account should appear in sign-in logs **only** during this kind of incident. Any other sign-in is either an emergency you know about, or an intrusion.
