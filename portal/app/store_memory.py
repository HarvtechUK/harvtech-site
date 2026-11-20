"""
In-memory implementation of the data layer.

Plain Python lists, seeded from sample_data. No Azure, no network, no
login — so the app runs instantly while you're learning. This is the
backend `store.py` selects when COSMOS_ENDPOINT is NOT set.

State lives only as long as the process: restart uvicorn and anything
you created is gone and the seed resets. That's the trade for zero setup;
store_cosmos.py is the one that persists.
"""

from . import sample_data
from .models import Engagement, Onboarding, ServiceRequest, Timesheet, User

# Copy the seed lists so mutating the store doesn't edit sample_data's
# own lists. (`list(...)` makes a new list; the objects inside are still
# shared, which is fine here.)
_engagements: list[Engagement] = list(sample_data.ENGAGEMENTS)
_timesheets: list[Timesheet] = list(sample_data.TIMESHEETS)
_users: list[User] = []  # empty locally; real portal users live in Cosmos
# Keyed by client id / request id. Dicts, because we always look these up
# by key, and a dict makes "save" the same one line whether new or changed.
_onboardings: dict[str, Onboarding] = {o.client_id: o for o in sample_data.onboardings()}
_requests: dict[str, ServiceRequest] = {r.id: r for r in sample_data.requests()}


def list_engagements() -> list[Engagement]:
    return _engagements


def get_engagement(engagement_id: str) -> Engagement | None:
    return next((e for e in _engagements if e.id == engagement_id), None)


def list_timesheets() -> list[Timesheet]:
    return _timesheets


def get_timesheet(timesheet_id: str) -> Timesheet | None:
    return next((t for t in _timesheets if t.id == timesheet_id), None)


def add_timesheet(timesheet: Timesheet) -> None:
    _timesheets.append(timesheet)


def save_timesheet(timesheet: Timesheet) -> None:
    # In memory we hold the object by reference, so mutating it has
    # already 'saved' it — nothing to do. The Cosmos backend does the
    # real persistence here.
    return None


def get_user(oid: str, tid: str) -> User | None:
    """Find a registered portal user by Entra object id + tenant id."""
    return next((u for u in _users if u.oid == oid and u.tid == tid), None)


# --- Client onboarding ---

def get_onboarding(client_id: str) -> Onboarding | None:
    return _onboardings.get(client_id)


def list_onboardings() -> list[Onboarding]:
    return list(_onboardings.values())


def save_onboarding(onboarding: Onboarding) -> None:
    _onboardings[onboarding.client_id] = onboarding


# --- Data-handling requests ---

def list_requests(client_id: str | None = None) -> list[ServiceRequest]:
    """One client's requests, or everyone's when client_id is None (staff only —
    the route decides who may ask for that)."""
    return [r for r in _requests.values() if client_id is None or r.client_id == client_id]


def get_request(request_id: str) -> ServiceRequest | None:
    return _requests.get(request_id)


def save_request(request: ServiceRequest) -> None:
    _requests[request.id] = request


def reset() -> None:
    """Put the store back to its seed. For tests, so one test's writes
    never leak into the next."""
    global _engagements, _timesheets, _users, _onboardings, _requests
    _engagements = list(sample_data.ENGAGEMENTS)
    _timesheets = [t.model_copy(deep=True) for t in sample_data.TIMESHEETS]
    _users = []
    _onboardings = {o.client_id: o for o in sample_data.onboardings()}
    _requests = {r.id: r for r in sample_data.requests()}
