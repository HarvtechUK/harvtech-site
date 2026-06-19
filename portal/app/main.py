"""
The portal API — application entry point.

Run it locally (from the portal/ directory, with your venv active):

    uvicorn app.main:app --reload

  - `app.main`  → the module path (the app/ package, main.py module)
  - `:app`      → the FastAPI object named `app`, defined below
  - `--reload`  → auto-restart when you save a file (handy while learning)

Then open http://127.0.0.1:8000/docs — FastAPI generates that interactive
API explorer automatically from the code in this file. Try the endpoints
there; it's the fastest way to see what each one returns.
"""

from fastapi import FastAPI, HTTPException

from . import sample_data
from .models import Engagement, Timesheet

# The single FastAPI application object. Every route (endpoint) is
# attached to it with a decorator like `@app.get(...)`. The title and
# version here show up at the top of the /docs page.
app = FastAPI(
    title="HarvTech Client Portal",
    summary="Timesheet and engagement approval for HarvTech clients.",
    version="0.1.0",
)


@app.get("/healthz")
def health_check() -> dict[str, str]:
    """A trivial 'is the app alive?' endpoint.

    Azure Container Apps will call this later as a health probe to know
    the container is up. Returning a dict — FastAPI serialises it to
    JSON automatically.
    """
    return {"status": "ok"}


# `@app.get(...)` registers a function to handle HTTP GET requests at a
# path. `response_model=list[Engagement]` tells FastAPI exactly what the
# endpoint returns: it validates the output against the model AND
# documents the response shape on the /docs page.
@app.get("/api/engagements", response_model=list[Engagement])
def list_engagements() -> list[Engagement]:
    """List every engagement.

    Later this will be scoped to the signed-in user's own client, once
    authentication is wired up. For now it returns the sample data.
    """
    return sample_data.ENGAGEMENTS


@app.get("/api/engagements/{engagement_id}", response_model=Engagement)
def get_engagement(engagement_id: str) -> Engagement:
    """Fetch one engagement by its id.

    `{engagement_id}` in the path becomes the function argument of the
    same name — FastAPI pulls it straight out of the URL and passes it
    in. If nothing matches, we raise `HTTPException`, which is how you
    return an error status (404 Not Found here) in FastAPI.
    """
    for engagement in sample_data.ENGAGEMENTS:
        if engagement.id == engagement_id:
            return engagement
    raise HTTPException(status_code=404, detail="Engagement not found")


@app.get("/api/timesheets", response_model=list[Timesheet])
def list_timesheets() -> list[Timesheet]:
    """List every timesheet.

    Each one comes back with its `total_days` filled in — remember that's
    the computed_field on the Timesheet model, summed from its entries.
    """
    return sample_data.TIMESHEETS


@app.get("/api/timesheets/{timesheet_id}/value")
def get_timesheet_value(timesheet_id: str) -> dict[str, float | str]:
    """Work out the money value of a timesheet: days × the engagement's rate.

    This lives in the API layer rather than on the model because it needs
    data from TWO places — the timesheet's day total and the parent
    engagement's day rate. A model only knows about its own fields, so
    'joining' two records together is the endpoint's job.
    """
    timesheet = next(
        (t for t in sample_data.TIMESHEETS if t.id == timesheet_id), None
    )
    if timesheet is None:
        raise HTTPException(status_code=404, detail="Timesheet not found")

    engagement = next(
        (e for e in sample_data.ENGAGEMENTS if e.id == timesheet.engagement_id),
        None,
    )
    if engagement is None:
        raise HTTPException(status_code=404, detail="Engagement not found")

    return {
        "timesheet_id": timesheet.id,
        "total_days": timesheet.total_days,
        "day_rate": engagement.day_rate,
        "currency": engagement.currency,
        "total_value": timesheet.total_days * engagement.day_rate,
    }
