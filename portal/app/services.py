"""
Domain services — the business rules, kept apart from HTTP and storage.

Three layers, each with one job:
  - routes (main.py = JSON API, web.py = HTML pages)  → HTTP concerns
  - services (this file)                               → the rules
  - store                                              → where data lives

Both sets of routes call into here, so the rules about what may happen to
a timesheet live in exactly one place — change them once and the API and
the web pages stay in step automatically.
"""

from . import store
from .models import Engagement, Timesheet, TimesheetStatus


class InvalidTransition(Exception):
    """A timesheet status change that isn't allowed from its current state
    (e.g. approving something never submitted). Each route turns this into
    the right response — a 409 for the API, a friendly message for the UI."""


# action -> (statuses it may be done FROM, the status it moves TO)
_TRANSITIONS: dict[str, tuple[set[TimesheetStatus], TimesheetStatus]] = {
    "submit": ({TimesheetStatus.DRAFT, TimesheetStatus.REJECTED}, TimesheetStatus.SUBMITTED),
    "approve": ({TimesheetStatus.SUBMITTED}, TimesheetStatus.APPROVED),
    "reject": ({TimesheetStatus.SUBMITTED}, TimesheetStatus.REJECTED),
}


def change_timesheet_status(timesheet: Timesheet, action: str) -> Timesheet:
    """Apply submit/approve/reject to a timesheet, enforcing the rules."""
    allowed_from, new_status = _TRANSITIONS[action]
    if timesheet.status not in allowed_from:
        raise InvalidTransition(
            f"Cannot {action} a timesheet that is '{timesheet.status.value}'."
        )
    timesheet.status = new_status
    store.save_timesheet(timesheet)
    return timesheet


def engagement_summary(engagement: Engagement) -> dict:
    """Delivery figures for an engagement: days approved, remaining, £ value.

    Built from APPROVED timesheets only — submitted-but-not-yet-approved
    days don't count until the client has signed them off, which is the
    whole point of the approval step.
    """
    approved = [
        t
        for t in store.list_timesheets()
        if t.engagement_id == engagement.id and t.status == TimesheetStatus.APPROVED
    ]
    days_approved = sum(t.total_days for t in approved)
    days_remaining = engagement.total_days - days_approved
    return {
        "days_approved": days_approved,
        "days_remaining": days_remaining,
        "value_approved": days_approved * engagement.day_rate,
        "percent_used": (
            round(days_approved / engagement.total_days * 100)
            if engagement.total_days
            else 0
        ),
    }
