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

from uuid import uuid4

from fastapi import FastAPI, HTTPException

from . import store
from .models import Engagement, Timesheet, TimesheetCreate, TimesheetStatus

app = FastAPI(
    title="HarvTech Client Portal",
    summary="Timesheet and engagement approval for HarvTech clients.",
    version="0.2.0",
)


@app.get("/healthz")
def health_check() -> dict[str, str]:
    """A trivial 'is the app alive?' endpoint (Container Apps health probe)."""
    return {"status": "ok"}


# ── Reads ────────────────────────────────────────────────────────────────────
# These now ask the `store` module for data rather than touching the data
# directly — see store.py for why that seam matters.

@app.get("/api/engagements", response_model=list[Engagement])
def list_engagements() -> list[Engagement]:
    """List every engagement. (Later: scoped to the signed-in user's client.)"""
    return store.list_engagements()


@app.get("/api/engagements/{engagement_id}", response_model=Engagement)
def get_engagement(engagement_id: str) -> Engagement:
    """Fetch one engagement by id, or 404 if there's no match."""
    engagement = store.get_engagement(engagement_id)
    if engagement is None:
        raise HTTPException(status_code=404, detail="Engagement not found")
    return engagement


@app.get("/api/timesheets", response_model=list[Timesheet])
def list_timesheets() -> list[Timesheet]:
    """List every timesheet, each with its computed total_days."""
    return store.list_timesheets()


@app.get("/api/timesheets/{timesheet_id}/value")
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
@app.post("/api/timesheets", response_model=Timesheet, status_code=201)
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


# Which statuses each action is allowed to move *from*. Encoding the rules
# as data keeps the three endpoints below short and makes the state
# machine obvious at a glance.
_ALLOWED_FROM: dict[str, set[TimesheetStatus]] = {
    "submit": {TimesheetStatus.DRAFT, TimesheetStatus.REJECTED},
    "approve": {TimesheetStatus.SUBMITTED},
    "reject": {TimesheetStatus.SUBMITTED},
}


def _change_status(
    timesheet_id: str, action: str, new_status: TimesheetStatus
) -> Timesheet:
    """Shared logic for the submit/approve/reject endpoints.

    Looks the timesheet up, checks the move is legal from its current
    status, applies it, and persists. An illegal move (e.g. approving a
    draft that was never submitted) returns 409 Conflict — the right code
    for "the request is valid but not allowed in the current state".
    """
    timesheet = store.get_timesheet(timesheet_id)
    if timesheet is None:
        raise HTTPException(status_code=404, detail="Timesheet not found")

    if timesheet.status not in _ALLOWED_FROM[action]:
        raise HTTPException(
            status_code=409,
            detail=f"Cannot {action} a timesheet that is '{timesheet.status.value}'.",
        )

    timesheet.status = new_status
    store.save_timesheet(timesheet)
    return timesheet


@app.post("/api/timesheets/{timesheet_id}/submit", response_model=Timesheet)
def submit_timesheet(timesheet_id: str) -> Timesheet:
    """Contractor action: send a draft (or rejected) timesheet for approval."""
    return _change_status(timesheet_id, "submit", TimesheetStatus.SUBMITTED)


@app.post("/api/timesheets/{timesheet_id}/approve", response_model=Timesheet)
def approve_timesheet(timesheet_id: str) -> Timesheet:
    """Client action: approve a submitted timesheet. This is what backs an invoice.

    (Later, auth will ensure only the client's own approver can call this,
    and only for their own client's timesheets.)
    """
    return _change_status(timesheet_id, "approve", TimesheetStatus.APPROVED)


@app.post("/api/timesheets/{timesheet_id}/reject", response_model=Timesheet)
def reject_timesheet(timesheet_id: str) -> Timesheet:
    """Client action: send a submitted timesheet back. It can be resubmitted."""
    return _change_status(timesheet_id, "reject", TimesheetStatus.REJECTED)
