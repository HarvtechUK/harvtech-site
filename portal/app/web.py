"""
The browser-facing pages — server-rendered HTML with Jinja2 templates.

These routes return HTML (a TemplateResponse) instead of JSON, but they
read and write through the same `store` and `services` as the JSON API in
main.py — so the data and the rules are identical, only the presentation
differs.

The submit/approve/reject actions are plain HTML <form> POSTs. After
handling one, we return a redirect rather than rendering directly — the
"Post/Redirect/Get" pattern. The browser then GETs the page fresh, so
hitting refresh won't re-submit the form. The redirect uses status 303
(See Other), the correct code for "done — now go and look over there".
"""

from pathlib import Path
from urllib.parse import quote

from fastapi import APIRouter, Request
from fastapi.responses import RedirectResponse

from fastapi.templating import Jinja2Templates

from . import services, store

# A router groups related routes; main.py attaches it with include_router.
router = APIRouter(tags=["web"])

# Jinja renders our .html files. The directory is found relative to this
# file, so it works regardless of where uvicorn is started from.
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


@router.get("/")
def dashboard(request: Request):
    """The landing page: each engagement with its delivery figures, plus
    the list of timesheets."""
    engagements = [
        {"engagement": e, "summary": services.engagement_summary(e)}
        for e in store.list_engagements()
    ]
    return templates.TemplateResponse(
        request,
        "dashboard.html",
        {"engagements": engagements, "timesheets": store.list_timesheets()},
    )


@router.get("/timesheets/{timesheet_id}")
def timesheet_detail(request: Request, timesheet_id: str):
    """One timesheet: its entries, totals, and the relevant action buttons."""
    timesheet = store.get_timesheet(timesheet_id)
    if timesheet is None:
        return RedirectResponse("/", status_code=303)

    engagement = store.get_engagement(timesheet.engagement_id)
    value = timesheet.total_days * engagement.day_rate if engagement else 0
    return templates.TemplateResponse(
        request,
        "timesheet_detail.html",
        {
            "ts": timesheet,
            "engagement": engagement,
            "value": value,
            # If a previous action bounced back with an error, show it.
            "error": request.query_params.get("error"),
        },
    )


@router.post("/timesheets/{timesheet_id}/{action}")
def timesheet_action(timesheet_id: str, action: str):
    """Handle a submit/approve/reject form post, then redirect back.

    The action comes from the URL (.../submit, .../approve, .../reject).
    On an illegal transition we bounce back to the detail page with the
    error in the query string, so the user sees why nothing happened.
    """
    if action not in {"submit", "approve", "reject"}:
        return RedirectResponse("/", status_code=303)

    timesheet = store.get_timesheet(timesheet_id)
    if timesheet is None:
        return RedirectResponse("/", status_code=303)

    try:
        services.change_timesheet_status(timesheet, action)
    except services.InvalidTransition as exc:
        return RedirectResponse(
            f"/timesheets/{timesheet_id}?error={quote(str(exc))}", status_code=303
        )
    return RedirectResponse(f"/timesheets/{timesheet_id}", status_code=303)
