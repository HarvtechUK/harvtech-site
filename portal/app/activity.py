"""
Recording what client users do in the portal, so HarvTech can see it.

"Has anyone at the client opened the report yet?" is a question worth
answering before a review meeting. This records three kinds of event for
CLIENT users only: signing in, viewing a page, and downloading a file.

What it deliberately does not do:
  - record HarvTech staff (including when they preview a client's page);
  - record anything typed, or which finding somebody looked at;
  - ever get in the way. A failure to write an event is logged and
    swallowed: a page must not break because its visit could not be noted.

The security and data-handling statement tells clients this is kept.
"""

import logging
from datetime import UTC, datetime
from uuid import uuid4

from . import access, store
from .models import ActivityEvent

log = logging.getLogger("portal.activity")

SIGN_IN, VIEW, DOWNLOAD = "sign_in", "view", "download"


def record(user: dict | None, kind: str, what: str = "") -> None:
    """Note that a client user did something. Staff and local mode are ignored."""
    client_id = access.client_of(user)
    if user is None or not client_id:
        return
    try:
        store.add_activity(
            ActivityEvent(
                id=f"act-{uuid4().hex}",
                client_id=client_id,
                at=datetime.now(UTC),
                who=user.get("email") or user.get("name") or user.get("oid") or "unknown",
                kind=kind,
                what=what,
            )
        )
    except Exception:  # noqa: BLE001 - never break a page over an activity note
        log.exception("could not record activity")


def summary(client_id: str) -> dict:
    """What the admin page shows for one client: who has been in, and what they opened."""
    events = store.list_activity(client_id, limit=500)
    people: dict[str, dict] = {}
    for event in events:  # newest first, so the first time we meet someone is their latest
        person = people.setdefault(
            event.who, {"who": event.who, "last_seen": event.at, "sign_ins": 0, "views": 0, "downloads": 0}
        )
        key = {SIGN_IN: "sign_ins", VIEW: "views", DOWNLOAD: "downloads"}.get(event.kind)
        if key:
            person[key] += 1
    report_views = [e for e in events if e.kind == VIEW and e.what == "Report"]
    downloads = [e for e in events if e.kind == DOWNLOAD]
    return {
        "people": sorted(people.values(), key=lambda p: p["last_seen"], reverse=True),
        "report_first_viewed": report_views[-1].at if report_views else None,
        "report_last_viewed": report_views[0].at if report_views else None,
        "report_views": len(report_views),
        "downloads": len(downloads),
        "recent": events[:25],
    }
