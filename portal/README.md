# HarvTech Client Portal — Python app

A multi-client timesheet and engagement-approval portal, built with
**FastAPI**. This is the application; the Azure platform it runs on
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
| `requirements.txt` | Declaring dependencies; venv workflow |

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
