# Runbook — onboarding a health-check client

How a new Azure health-check client goes from "signed" to "ready to
scan", using the portal's onboarding pages and `finops preflight`.

## 1. Give the client's people a way in

Each person needs a `users` document, exactly as for a timesheet
approver (see `external-id-setup.md` for how sign-in works). Two roles
exist for clients:

- `client_technical`: the platform or security contact. Sees onboarding
  only. Use this for almost everyone.
- `client_approver`: the budget holder. Sees timesheets and day rates as
  well, so only for the person who approves invoices.

```json
{
  "id": "<their Entra object id>",
  "oid": "<their Entra object id>",
  "tid": "<their tenant id>",
  "email": "name@client.example",
  "name": "Their Name",
  "role": "client_technical",
  "client_id": "client-example"
}
```

The `client_id` is what ties their sign-in to their checklist. It must be
identical on every user of that client and on the onboarding you open
next. A client user with no `client_id` sees nothing.

## 2. Open the onboarding

Portal → **Onboarding** (the admin list) → *Open an onboarding*. Give the
same client id, the client's name as they should read it, and tick the
tiers the engagement includes. Reader (A) and the two context
conversations (X) are always included.

## 3. The client works through the checklist

They sign in, read the onboarding guide, accept the security and
data-handling statement, and mark items done as their administrators
grant each role. Each action is logged, appears on the admin pages, and
is posted to `NOTIFY_WEBHOOK_URL` if that is set on the container app.

## 4. Verify what they say is done

With the scan identity signed in, from the `harvtech-finops` repository:

```bash
cd engine && uv run finops preflight --customer "Client Name" --out preflight.json
```

It makes one read-only probe per grant and prints what worked. Then:
Portal → the client's admin page → *Import a preflight result* → paste
the contents of `preflight.json`. Verified probes mark their items
verified; failed and partial ones mark them "needs attention" with the
probe's own sentence, which the client sees; items the probe could not
check are left alone.

Items a probe cannot check (the script packs, the two conversations) are
verified by hand on the same page, with a line saying what was confirmed.

## 5. Ready to scan

Tier A verified is the bar for a first scan; the dashboard then says
"Ready for the first scan". Everything else adds depth and can follow.

## Requests

A client can ask, from **Requests**, for the things the statement
promises. They arrive on the admin **Requests** page. Closing one needs a
written response, because the statement says we confirm in writing. For
"delete everything you hold about us" that means running
`finops forget --customer "Client Name" --yes` first and quoting what it
removed.
