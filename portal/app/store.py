"""
The data layer — every read and write of portal data goes through here.

Today it's plain Python lists held in memory (seeded from sample_data).
Later it becomes Azure Cosmos DB. The whole point of this module is that
when that swap happens, we reimplement the functions *in this one file*
and the rest of the app — the endpoints in main.py — keeps calling
`store.get_timesheet(...)` exactly as before. That separation (the API
asks the store for data, the store decides where data lives) is worth
internalising early; it's how real apps stay changeable.

Caveat while in memory: state lives only as long as the process. Restart
uvicorn and any timesheets you created are gone, and the seed data
resets. Persistence arrives with Cosmos.
"""

from . import sample_data
from .models import Engagement, Timesheet

# Copy the seed lists so mutating the store doesn't edit the sample_data
# module's own lists. (`list(...)` makes a new list; the Engagement/
# Timesheet objects inside are still shared, which is fine here.)
_engagements: list[Engagement] = list(sample_data.ENGAGEMENTS)
_timesheets: list[Timesheet] = list(sample_data.TIMESHEETS)


# --- Engagements (read-only for now) ---

def list_engagements() -> list[Engagement]:
    return _engagements


def get_engagement(engagement_id: str) -> Engagement | None:
    """Return the engagement with this id, or None if there isn't one.

    Returning None rather than raising lets the *caller* decide what a
    miss means (a 404 to the user, say). The store's job is data, not
    HTTP."""
    return next((e for e in _engagements if e.id == engagement_id), None)


# --- Timesheets (read + write) ---

def list_timesheets() -> list[Timesheet]:
    return _timesheets


def get_timesheet(timesheet_id: str) -> Timesheet | None:
    return next((t for t in _timesheets if t.id == timesheet_id), None)


def add_timesheet(timesheet: Timesheet) -> None:
    """Store a newly created timesheet."""
    _timesheets.append(timesheet)


def save_timesheet(timesheet: Timesheet) -> None:
    """Persist changes to an existing timesheet (e.g. a status change).

    In memory this is essentially a no-op — we're holding the very same
    object by reference, so mutating it has already 'saved' it. We still
    route status changes through here so the call site reads correctly,
    and so the Cosmos version has an obvious home for its `upsert`."""
    # With Cosmos this becomes: container.upsert_item(timesheet.model_dump())
    return None
