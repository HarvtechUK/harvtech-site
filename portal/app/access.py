"""
Who may see and do what — the authorisation rules, in one place.

Authentication (auth.py) proves WHO someone is and that they have a portal
record. This module answers the next question on every request: is THIS
user allowed to see THIS client's data, or take THIS action?

The rule that matters most: a client user only ever sees their own
client's records. The design (docs/architecture/portal-hld.md, section 4)
says the server enforces that on every call, and this is where it does.
Routes never filter by hand; they call `scoped(...)` or `can_see_client(...)`
so the rule cannot be forgotten on one page and remembered on another.

Roles:
  admin             HarvTech. Sees every client, does everything.
  contractor        HarvTech delivery. Sees every client, submits timesheets.
  client_approver   The client's budget holder. Their own client only:
                    timesheets (approve / reject) and onboarding.
  client_technical  The client's platform or security contact. Their own
                    client only, and ONLY onboarding: never timesheets or
                    day rates, which are commercial.

`user` is the dict auth.py stores in the session, or None when sign-in is
disabled for local development — and None is treated as HarvTech staff,
because open mode only ever runs against throwaway in-memory data
(config.check_safe_to_start refuses anything else).
"""

from collections.abc import Iterable
from typing import Protocol, TypeVar

ADMIN = "admin"
CONTRACTOR = "contractor"
CLIENT_APPROVER = "client_approver"
CLIENT_TECHNICAL = "client_technical"

STAFF_ROLES = {ADMIN, CONTRACTOR}
CLIENT_ROLES = {CLIENT_APPROVER, CLIENT_TECHNICAL}


class HasClient(Protocol):
    """Anything with a client_id — engagements, timesheets, requests."""

    client_id: str


T = TypeVar("T", bound=HasClient)


def role_of(user: dict | None) -> str:
    """The user's role; local open mode (no user) counts as admin."""
    return ADMIN if user is None else str(user.get("role") or "")


def is_staff(user: dict | None) -> bool:
    return role_of(user) in STAFF_ROLES


def is_admin(user: dict | None) -> bool:
    return role_of(user) == ADMIN


def client_of(user: dict | None) -> str | None:
    """The one client a client user belongs to (None for staff)."""
    if user is None or is_staff(user):
        return None
    return user.get("client_id") or None


def can_see_client(user: dict | None, client_id: str | None) -> bool:
    """Staff see every client. A client user sees exactly their own.

    A client user with no client_id on their record sees nothing: a
    half-configured account must fail closed, not open.
    """
    if is_staff(user):
        return True
    if role_of(user) not in CLIENT_ROLES:
        return False
    own = client_of(user)
    return bool(own) and own == client_id


def scoped(items: Iterable[T], user: dict | None) -> list[T]:
    """Only the records this user may see. Use it on every list."""
    return [item for item in items if can_see_client(user, item.client_id)]


def can_see_timesheets(user: dict | None) -> bool:
    """Timesheets carry day rates: staff and the client's approver only."""
    return is_staff(user) or role_of(user) == CLIENT_APPROVER


def can_see_onboarding(user: dict | None) -> bool:
    return is_staff(user) or role_of(user) in CLIENT_ROLES


def can_change_timesheet(user: dict | None, action: str, client_id: str) -> bool:
    """Who may submit, approve or reject.

    Submitting is HarvTech's side. Approving and rejecting are the
    client's decision: their approver (for their own client), or an admin
    acting on a client's written instruction. A contractor can never
    approve their own work.
    """
    if not can_see_client(user, client_id):
        return False
    if action == "submit":
        return is_staff(user)
    if action in ("approve", "reject"):
        return is_admin(user) or role_of(user) == CLIENT_APPROVER
    return False
