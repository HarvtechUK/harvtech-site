"""
Telling HarvTech that a client did something that needs a response.

Two things happen on every event. It is written to the application log
(which Container Apps keeps), and the admin pages show it as work waiting
— that is the dependable part. On top, if NOTIFY_WEBHOOK_URL is set, the
event is POSTed as JSON to that address: a Teams channel webhook or a
Logic App that turns it into an email. That part is best effort, so a
slow or broken webhook can never make a client's button fail.

Nothing sensitive goes in the payload: the client's name, who acted, and
a one-line summary. The detail stays in the portal, behind sign-in.
"""

import json
import logging
import os
import urllib.request

log = logging.getLogger("portal.notify")

WEBHOOK_URL = os.environ.get("NOTIFY_WEBHOOK_URL", "")
PORTAL_URL = os.environ.get("PORTAL_PUBLIC_URL", "")
TIMEOUT_SECONDS = 5


def notify(kind: str, client_name: str, who: str, summary: str, path: str = "") -> None:
    """Record an event for HarvTech, and push it to the webhook if there is one.

    `kind` is a short machine name ("item_done", "request_raised",
    "statement_acknowledged"); `path` is where in the portal to look.
    """
    payload = {
        "kind": kind,
        "client": client_name,
        "who": who,
        "summary": summary,
        "link": f"{PORTAL_URL}{path}" if PORTAL_URL and path else path,
        # Teams' simple incoming webhooks show a top-level "text" field.
        "text": f"{client_name}: {summary} ({who})",
    }
    log.info("notify %s", json.dumps(payload))
    if not WEBHOOK_URL:
        return
    try:
        request = urllib.request.Request(
            WEBHOOK_URL,
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS):  # noqa: S310
            pass
    except Exception:  # noqa: BLE001 - a notification must never break the page
        log.exception("notify webhook failed")
