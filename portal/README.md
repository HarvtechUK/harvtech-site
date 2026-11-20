# HarvTech Client Portal — Python app

A multi-client portal built with **FastAPI**: timesheet and
engagement approval, and onboarding for Azure health-check clients (a
checklist the client works through, a readiness dashboard, the security
and data-handling statement, and requests to HarvTech). This is the application; the Azure platform it runs on
(Container Apps, Cosmos DB, identity) lives in the `portal-platform/`
Terraform stack. Design: [`docs/architecture/portal-hld.md`](../docs/architecture/portal-hld.md).

> Built in small, explained steps as a Python learning project. The code
> is deliberately heavily commented — read it top to bottom.

## Run it locally

From this `portal/` directory:

```bash
# 1. Create a virtual environment (an isolated per-project Python).
python3.13 -m venv .venv

# 2. Activate it (your shell prompt will show (.venv)).
source .venv/bin/activate

# 3. Install the dependencies into it.
pip install -r requirements.txt

# 4. Run the app with auto-reload.
uvicorn app.main:app --reload
```

Then open:

- <http://127.0.0.1:8000/docs> — the interactive API explorer FastAPI
  builds for you. Click an endpoint → "Try it out" → "Execute".
- <http://127.0.0.1:8000/api/engagements> — raw JSON of the sample data.

`Ctrl+C` stops the server. `deactivate` leaves the venv.

## What's here so far

| File | What it teaches |
|---|---|
| `app/models.py` | Pydantic models — typed, validated data shapes; input vs stored models |
| `app/main.py` | The FastAPI app: read + write endpoints, status transitions, error codes |
| `app/store.py` | The data layer — picks a backend by config and re-exports it |
| `app/store_memory.py` | In-memory backend (default; no Azure needed) |
| `app/store_cosmos.py` | Cosmos DB backend (keyless, via managed identity) |
| `app/sample_data.py` | Seed data for the in-memory backend (first client: 40 days @ £650) |
| `app/access.py` | Authorisation: who may see which client, and do what |
| `app/onboarding_catalogue.py` | The checklist as data: tiers, items, the words the client reads |
| `app/onboarding_services.py` | The onboarding rules and the readiness arithmetic |
| `app/onboarding_web.py` | The onboarding pages, client and admin |
| `app/notify.py` | Telling HarvTech a client did something (log, plus an optional webhook) |
| `tests/` | The app run as different users; client isolation proved |
| `requirements.txt` | Declaring dependencies; venv workflow |

## Run the tests

```bash
pip install -r requirements.txt -r requirements-dev.txt
pytest
```

The tests run the real app on the in-memory store and sign in as
different people by replacing one dependency (see `tests/conftest.py`).
The ones that matter most prove a client cannot see or change another
client's records.

## Who can see what

Every route asks `app/access.py`, and nothing else decides:

| Role | Sees | Can do |
|---|---|---|
| `admin` | Every client | Everything |
| `contractor` | Every client | Submit timesheets; verify onboarding |
| `client_approver` | Their own client only | Approve or reject timesheets; onboarding |
| `client_technical` | Their own client only, onboarding only | Never timesheets or day rates |

A record the user may not see behaves exactly like one that does not
exist (a 404, or a redirect home), so the portal never confirms another
client's data is there.

## Client onboarding

A health-check client grants read-only access in tiers. The portal turns
that into a checklist with one rule: **the client says "done"; only
HarvTech says "verified".**

| Page | Who | What |
|---|---|---|
| `/onboarding` | Client | Readiness dashboard and checklist; mark items done |
| `/documents/onboarding` | Client | The guide, generated from the checklist catalogue |
| `/documents/security` | Client | The security and data-handling statement, with an accept button |
| `/requests` | Client | Ask HarvTech to delete data, send findings, rotate the scan identity... |
| `/admin/onboarding` | HarvTech | Every client's readiness; open a new onboarding |
| `/admin/onboarding/{client}` | HarvTech | Verify each item; import a `finops preflight` file |
| `/admin/requests` | HarvTech | Answer requests in writing |

Locally (no sign-in) you are treated as an admin. Open
<http://127.0.0.1:8000/admin/onboarding>, or see the sample client's own
view at <http://127.0.0.1:8000/onboarding?client=client-demo>.

The checklist item ids (`A1`, `B1`, `C1`...) are shared with the scanning
engine: `finops preflight` in the `harvtech-finops` repository probes each
grant read-only and writes a JSON file keyed by the same ids, which the
admin page imports. Runbook:
[`docs/runbooks/client-onboarding.md`](../docs/runbooks/client-onboarding.md).

When a client marks an item done, accepts the statement or raises a
request, HarvTech is told: it is logged, it shows on the admin pages, and
if `NOTIFY_WEBHOOK_URL` is set the event is posted there as JSON (a Teams
webhook, or a Logic App that sends an email).

## Choosing the data backend

The app uses Cosmos DB when `COSMOS_ENDPOINT` is set, and the in-memory
store otherwise. `GET /healthz` tells you which is live.

```bash
# In-memory (default) — nothing to set, just run.
uvicorn app.main:app --reload

# Real Cosmos DB — sign in first (keyless auth uses your az login),
# then point at the account:
az login
export COSMOS_ENDPOINT="https://cosno-harvtech-portal-prd-uks-01.documents.azure.com:443/"
export COSMOS_DATABASE="portal"   # optional; this is the default
uvicorn app.main:app --reload
```

(The Cosmos account and your data-plane role assignment come from the
`portal-platform/` Terraform stack — so the Cosmos path works end-to-end
once that's deployed.)

## What's coming (later steps)

1. **Authentication** — sign-in via Microsoft Entra External ID, with
   per-client scoping so an approver only sees their own data.
2. **A UI** — server-rendered pages (Jinja templates) over these endpoints.
3. **Docker + Container Apps** — containerise and deploy.
