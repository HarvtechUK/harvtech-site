"""
The portal API — application entry point.

Run it locally (from the portal/ directory, with your venv active):

    uvicorn app.main:app --reload

  - `app.main`  → the module path (the app/ package, main.py module)
  - `:app`      → the FastAPI object named `app`, defined below
  - `--reload`  → auto-restart when you save a file (handy while learning)

Then open http://127.0.0.1:8000/docs — FastAPI generates that interactive
API explorer automatically from the code in this file. You can create and
approve timesheets straight from that page: "Try it out" → edit the JSON
→ "Execute".
"""

from pathlib import Path
from uuid import uuid4

from fastapi import Depends, FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware

from . import auth, services, store, web
from .auth import require_user
from .config import settings
from .models import Engagement, Timesheet, TimesheetCreate, TimesheetStatus

app = FastAPI(
    title="HarvTech Client Portal",
    summary="Timesheet and engagement approval for HarvTech clients.",
    version="0.4.0",
)

# Signed session cookie — holds the logged-in user and the in-flight
# sign-in state. https_only when auth is on (i.e. deployed behind TLS).
app.add_middleware(
    SessionMiddleware,
    secret_key=settings.session_secret,
    same_site="lax",       # allows the cookie on the top-level redirect back from Microsoft
    https_only=settings.auth_enabled,
)

# The sign-in routes (/auth/*) are public — they ARE the way in, so they
# can't require a login themselves.
app.include_router(auth.router)

# The browser-facing HTML pages (web.py) require a signed-in, registered
# user. require_user redirects to /auth/login if not — or lets everything
# through when auth is disabled (local dev).
app.include_router(web.router, dependencies=[Depends(require_user)])

# Serve the CSS (and any future images) from app/static at /static.
# Path(__file__).parent is the app/ directory, found relative to THIS
# file so it works no matter where the app is launched from.
app.mount("/static", StaticFiles(directory=Path(__file__).parent / "static"), name="static")


@app.get("/healthz")
def health_check() -> dict[str, str]:
    """A trivial 'is the app alive?' endpoint (Container Apps health probe).

    Also reports which data backend is live — a quick way to confirm
    whether you're on in-memory or real Cosmos right now.
    """
    return {"status": "ok", "backend": store.BACKEND_NAME}


# ── Reads ────────────────────────────────────────────────────────────────────
# These now ask the `store` module for data rather than touching the data
# directly — see store.py for why that seam matters.

@app.get("/api/engagements", response_model=list[Engagement], dependencies=[Depends(require_user)])
def list_engagements() -> list[Engagement]:
    """List every engagement. (Later: scoped to the signed-in user's client.)"""
    return store.list_engagements()


@app.get("/api/engagements/{engagement_id}", response_model=Engagement, dependencies=[Depends(require_user)])
def get_engagement(engagement_id: str) -> Engagement:
    """Fetch one engagement by id, or 404 if there's no match."""
    engagement = store.get_engagement(engagement_id)
    if engagement is None:
        raise HTTPException(status_code=404, detail="Engagement not found")
    return engagement


@app.get("/api/timesheets", response_model=list[Timesheet], dependencies=[Depends(require_user)])
def list_timesheets() -> list[Timesheet]:
    """List every timesheet, each with its computed total_days."""
    return store.list_timesheets()


@app.get("/api/timesheets/{timesheet_id}/value", dependencies=[Depends(require_user)])
def get_timesheet_value(timesheet_id: str) -> dict[str, float | str]:
    """Money value of a timesheet: days × the engagement's day rate.

    Lives here (not on the model) because it needs data from two records —
    the timesheet's day total and the parent engagement's rate.
    """
    timesheet = store.get_timesheet(timesheet_id)
    if timesheet is None:
        raise HTTPException(status_code=404, detail="Timesheet not found")
    engagement = store.get_engagement(timesheet.engagement_id)
    if engagement is None:
        raise HTTPException(status_code=404, detail="Engagement not found")
    return {
        "timesheet_id": timesheet.id,
        "total_days": timesheet.total_days,
        "day_rate": engagement.day_rate,
        "currency": engagement.currency,
        "total_value": timesheet.total_days * engagement.day_rate,
    }


# ── Writes ───────────────────────────────────────────────────────────────────

# `new: TimesheetCreate` is the key line. When a function parameter is a
# Pydantic model, FastAPI reads the request's JSON body, validates it
# against that model, and hands you a ready-made object — or returns a
# 422 with a precise error if the body is wrong. You never parse JSON by
# hand. `status_code=201` is the HTTP "Created" code for a successful POST.
@app.post("/api/timesheets", response_model=Timesheet, status_code=201, dependencies=[Depends(require_user)])
def create_timesheet(new: TimesheetCreate) -> Timesheet:
    """Create a new draft timesheet against an engagement.

    The server fills in every trusted field itself — id, status, and the
    client/contractor copied from the engagement — rather than taking
    them from the request. That's the input-model discipline from
    models.py put into practice.
    """
    engagement = store.get_engagement(new.engagement_id)
    if engagement is None:
        raise HTTPException(status_code=404, detail="Engagement not found")

    timesheet = Timesheet(
        id=f"ts-{uuid4().hex[:12]}",          # server-generated unique id
        client_id=engagement.client_id,        # derived, not trusted from input
        engagement_id=engagement.id,
        contractor_id=engagement.contractor_id,
        period=new.period,
        entries=new.entries,
        status=TimesheetStatus.DRAFT,          # always starts as a draft
    )
    store.add_timesheet(timesheet)
    return timesheet


def _api_transition(timesheet_id: str, action: str) -> Timesheet:
    """Shared logic for the submit/approve/reject API endpoints.

    Find the timesheet (404 if missing), then defer the *rule* to the
    services layer. An illegal move raises InvalidTransition, which we
    translate to 409 Conflict — the right code for 'valid request, not
    allowed in the current state' (distinct from 404 and from 422).
    """
    timesheet = store.get_timesheet(timesheet_id)
    if timesheet is None:
        raise HTTPException(status_code=404, detail="Timesheet not found")
    try:
        return services.change_timesheet_status(timesheet, action)
    except services.InvalidTransition as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@app.post("/api/timesheets/{timesheet_id}/submit", response_model=Timesheet, dependencies=[Depends(require_user)])
def submit_timesheet(timesheet_id: str) -> Timesheet:
    """Contractor action: send a draft (or rejected) timesheet for approval."""
    return _api_transition(timesheet_id, "submit")


@app.post("/api/timesheets/{timesheet_id}/approve", response_model=Timesheet, dependencies=[Depends(require_user)])
def approve_timesheet(timesheet_id: str) -> Timesheet:
    """Client action: approve a submitted timesheet. This is what backs an invoice."""
    return _api_transition(timesheet_id, "approve")


@app.post("/api/timesheets/{timesheet_id}/reject", response_model=Timesheet, dependencies=[Depends(require_user)])
def reject_timesheet(timesheet_id: str) -> Timesheet:
    """Client action: send a submitted timesheet back. It can be resubmitted."""
    return _api_transition(timesheet_id, "reject")
