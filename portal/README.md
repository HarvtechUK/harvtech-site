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

## What's here so far (step 1)

| File | What it teaches |
|---|---|
| `app/models.py` | Pydantic models — typed, validated data shapes |
| `app/sample_data.py` | In-memory stand-in data (Cosmos comes later) |
| `app/main.py` | The FastAPI app and its read-only endpoints |
| `requirements.txt` | Declaring dependencies; venv workflow |

## What's coming (later steps)

1. **Write operations** — create/submit a timesheet, approve/reject it.
2. **A data layer** — swap `sample_data.py` for Azure Cosmos DB, reached
   with the app's managed identity (no keys).
3. **Authentication** — sign-in via Microsoft Entra External ID, with
   per-client scoping so an approver only sees their own data.
4. **A UI** — server-rendered pages (Jinja templates) over these endpoints.
5. **Docker + Container Apps** — containerise and deploy.
