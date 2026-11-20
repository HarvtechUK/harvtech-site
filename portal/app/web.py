"""
The browser-facing pages — server-rendered HTML with Jinja2 templates.

These routes return HTML (a TemplateResponse) instead of JSON, but they
read and write through the same `store` and `services` as the JSON API in
main.py — so the data and the rules are identical, only the presentation
differs.

Every route takes the signed-in `user` and asks `access` what that user
may see: lists go through `access.scoped(...)`, single records through
`access.can_see_client(...)`. A record the user may not see is treated
exactly like one that does not exist, so the portal never confirms that
another client's timesheet is there.

The submit/approve/reject actions are plain HTML <form> POSTs. After
handling one, we return a redirect rather than rendering directly — the
"Post/Redirect/Get" pattern. The browser then GETs the page fresh, so
hitting refresh won't re-submit the form. The redirect uses status 303
(See Other), the correct code for "done — now go and look over there".
"""

from pathlib import Path
from urllib.parse import quote

from fastapi import APIRouter, Depends, Request
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates

from . import access, services, store
from .auth import require_user

# A router groups related routes; main.py attaches it with include_router.
router = APIRouter(tags=["web"])

# Jinja renders our .html files. The directory is found relative to this
# file, so it works regardless of where uvicorn is started from.
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")


def nav_for(user: dict | None) -> list[dict]:
    """The links in the top bar, by what this user may open."""
    links = []
    if access.can_see_timesheets(user):
        links.append({"href": "/", "label": "Timesheets"})
    if access.is_staff(user):
        links.append({"href": "/admin/onboarding", "label": "Onboarding"})
        links.append({"href": "/admin/activity", "label": "Activity"})
    elif access.can_see_onboarding(user):
        links.append({"href": "/onboarding", "label": "Onboarding"})
        links.append({"href": "/report", "label": "Report"})
        links.append({"href": "/documents/security", "label": "Security"})
        links.append({"href": "/requests", "label": "Requests"})
    return links


@router.get("/")
def dashboard(request: Request, user: dict | None = Depends(require_user)):
    """The landing page: each engagement with its delivery figures, plus
    the list of timesheets — only this user's client's, unless staff."""
    if not access.can_see_timesheets(user):
        # A technical contact has no business with day rates; their home
        # page is the onboarding dashboard.
        return RedirectResponse("/onboarding", status_code=303)
    engagements = [
        {"engagement": e, "summary": services.engagement_summary(e)}
        for e in access.scoped(store.list_engagements(), user)
    ]
    return templates.TemplateResponse(
        request,
        "dashboard.html",
        {
            "engagements": engagements,
            "timesheets": access.scoped(store.list_timesheets(), user),
            "user": user,
            "nav": nav_for(user),
        },
    )


@router.get("/timesheets/{timesheet_id}")
def timesheet_detail(
    request: Request, timesheet_id: str, user: dict | None = Depends(require_user)
):
    """One timesheet: its entries, totals, and the relevant action buttons."""
    timesheet = store.get_timesheet(timesheet_id)
    if (
        timesheet is None
        or not access.can_see_timesheets(user)
        or not access.can_see_client(user, timesheet.client_id)
    ):
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
            "user": user,
            "nav": nav_for(user),
            # The template only draws the buttons this user may press.
            "can_submit": access.can_change_timesheet(user, "submit", timesheet.client_id),
            "can_decide": access.can_change_timesheet(user, "approve", timesheet.client_id),
        },
    )


@router.post("/timesheets/{timesheet_id}/{action}")
def timesheet_action(
    timesheet_id: str, action: str, user: dict | None = Depends(require_user)
):
    """Handle a submit/approve/reject form post, then redirect back.

    The action comes from the URL (.../submit, .../approve, .../reject).
    On an illegal transition we bounce back to the detail page with the
    error in the query string, so the user sees why nothing happened.
    Hiding a button in the template is a courtesy; THIS check is the
    control, because anyone can post to a URL by hand.
    """
    if action not in {"submit", "approve", "reject"}:
        return RedirectResponse("/", status_code=303)

    timesheet = store.get_timesheet(timesheet_id)
    if timesheet is None or not access.can_see_client(user, timesheet.client_id):
        return RedirectResponse("/", status_code=303)
    if not access.can_change_timesheet(user, action, timesheet.client_id):
        message = f"Your role may not {action} a timesheet."
        return RedirectResponse(
            f"/timesheets/{timesheet_id}?error={quote(message)}", status_code=303
        )

    try:
        services.change_timesheet_status(timesheet, action)
    except services.InvalidTransition as exc:
        return RedirectResponse(
            f"/timesheets/{timesheet_id}?error={quote(str(exc))}", status_code=303
        )
    return RedirectResponse(f"/timesheets/{timesheet_id}", status_code=303)
