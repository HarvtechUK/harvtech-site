"""
Onboarding rules — what may happen to a checklist, and how ready a client is.

Same layering as services.py: routes handle HTTP, this module holds the
rules, the store holds the data. The one rule everything else hangs off:

    the client says "done"; only HarvTech says "verified".

So there are two sets of functions here. `mark_done` / `undo_done` /
`acknowledge_statement` / `raise_request` are the client's moves.
`check_item` / `import_preflight` / `update_request` are HarvTech's. The
routes decide who is calling; these functions decide what is legal.
"""

from datetime import UTC, datetime
from uuid import uuid4

from . import store
from .models import (
    ItemState,
    ItemStatus,
    Onboarding,
    OnboardingEvent,
    RequestStatus,
    ServiceRequest,
)
from .onboarding_catalogue import DEFAULT_TIERS, ITEM_BY_ID, ITEMS, TIER_BY_KEY, TIERS, TOTAL_RULES

# The version of the security and data-handling statement on the page. Bump
# it when the wording changes, and clients are asked to accept it again.
STATEMENT_VERSION = "1"
HISTORY_LIMIT = 100
MAX_TEXT = 2000

# What a client can ask for. Each is a promise the statement makes; the
# words are what the client sees on the request form.
REQUEST_KINDS: dict[str, dict[str, str]] = {
    "delete_data": {
        "label": "Delete everything you hold about us",
        "help": "Every scan, snapshot and finding, in one operation. We confirm in writing when it is done.",
    },
    "export_findings": {
        "label": "Send us our findings",
        "help": "The current findings as CSV, Excel or the PDF report, to the contact you name.",
    },
    "access_report": {
        "label": "Tell us who can see our data",
        "help": "The named people at HarvTech with access, and when our data was last opened.",
    },
    "rotate_identity": {
        "label": "Rotate or retire the scan identity",
        "help": "We rotate the credential we hold, or stop using it so you can delete the identity.",
    },
    "pause_scans": {
        "label": "Pause scanning",
        "help": "No further scans until you tell us to resume, for a change freeze or an incident.",
    },
    "question": {
        "label": "A security or data-handling question",
        "help": "Anything your security team needs answered in writing.",
    },
}


class NotAllowed(Exception):
    """A move the rules forbid — routes turn it into a message for the user."""


def _now() -> datetime:
    return datetime.now(UTC)


def _log(onboarding: Onboarding, who: str, what: str) -> None:
    """Append to the audit trail, newest last, capped so the document stays small."""
    onboarding.history.append(OnboardingEvent(at=_now(), who=who, what=what))
    del onboarding.history[:-HISTORY_LIMIT]


def items_in_scope(onboarding: Onboarding) -> list:
    """The catalogue items this client's engagement includes, in catalogue order."""
    return [item for item in ITEMS if item.tier in onboarding.tiers]


def state_of(onboarding: Onboarding, item_id: str) -> ItemState:
    return onboarding.items.get(item_id) or ItemState()


# ── The client's moves ───────────────────────────────────────────────────────

def start(client_id: str, client_name: str, tiers: list[str], who: str) -> Onboarding:
    """Open an onboarding for a client (HarvTech does this once per engagement)."""
    client_id, client_name = client_id.strip(), client_name.strip()
    if not client_id or not client_name:
        raise NotAllowed("A client id and a client name are both needed.")
    if store.get_onboarding(client_id) is not None:
        raise NotAllowed(f"{client_id} already has an onboarding.")
    chosen = [t.key for t in TIERS if t.key in (tiers or DEFAULT_TIERS)]
    # Tier A is the engagement: nothing else works without it. The context
    # conversations always apply too.
    for always in ("A", "X"):
        if always not in chosen:
            chosen.append(always)
    onboarding = Onboarding(
        id=client_id,
        client_id=client_id,
        client_name=client_name,
        tiers=[t.key for t in TIERS if t.key in chosen],
        created_at=_now(),
    )
    _log(onboarding, who, "Onboarding opened")
    store.save_onboarding(onboarding)
    return onboarding


def mark_done(onboarding: Onboarding, item_id: str, who: str) -> None:
    """The client says a line is done. It now waits for HarvTech to verify."""
    item = ITEM_BY_ID.get(item_id)
    if item is None or item.tier not in onboarding.tiers:
        raise NotAllowed("That item is not part of this onboarding.")
    state = state_of(onboarding, item_id)
    if state.status == ItemStatus.VERIFIED:
        raise NotAllowed("That item is already verified.")
    # From TODO, or from NEEDS_ATTENTION once they have fixed what we found.
    onboarding.items[item_id] = ItemState(
        status=ItemStatus.DONE, done_by=who, done_at=_now(), detail=""
    )
    _log(onboarding, who, f"Marked {item_id} as done")
    store.save_onboarding(onboarding)


def undo_done(onboarding: Onboarding, item_id: str, who: str) -> None:
    """The client takes back a "done" they pressed by mistake."""
    state = state_of(onboarding, item_id)
    if state.status != ItemStatus.DONE:
        raise NotAllowed("Only an item waiting for verification can be reopened.")
    onboarding.items[item_id] = ItemState()
    _log(onboarding, who, f"Reopened {item_id}")
    store.save_onboarding(onboarding)


def acknowledge_statement(onboarding: Onboarding, who: str) -> None:
    onboarding.statement_acknowledged_by = who
    onboarding.statement_acknowledged_at = _now()
    onboarding.statement_version = STATEMENT_VERSION
    _log(
        onboarding,
        who,
        f"Accepted the security and data-handling statement (version {STATEMENT_VERSION})",
    )
    store.save_onboarding(onboarding)


def statement_current(onboarding: Onboarding) -> bool:
    """Has someone at the client accepted the version now on the page?"""
    return bool(
        onboarding.statement_acknowledged_at
        and onboarding.statement_version == STATEMENT_VERSION
    )


def raise_request(client_id: str, kind: str, detail: str, who: str) -> ServiceRequest:
    if kind not in REQUEST_KINDS:
        raise NotAllowed("Choose one of the request types listed.")
    request = ServiceRequest(
        id=f"req-{uuid4().hex[:12]}",
        client_id=client_id,
        kind=kind,
        detail=detail.strip()[:MAX_TEXT],
        raised_by=who,
        raised_at=_now(),
    )
    store.save_request(request)
    return request


# ── HarvTech's moves ─────────────────────────────────────────────────────────

def check_item(
    onboarding: Onboarding, item_id: str, passed: bool, detail: str, who: str, *, save: bool = True
) -> None:
    """HarvTech records the result of checking a line: verified, or needs attention."""
    item = ITEM_BY_ID.get(item_id)
    if item is None or item.tier not in onboarding.tiers:
        raise NotAllowed("That item is not part of this onboarding.")
    previous = state_of(onboarding, item_id)
    onboarding.items[item_id] = ItemState(
        status=ItemStatus.VERIFIED if passed else ItemStatus.NEEDS_ATTENTION,
        # Keep who at the client did it; a check does not erase that.
        done_by=previous.done_by,
        done_at=previous.done_at,
        checked_by=who,
        checked_at=_now(),
        detail=detail.strip()[:MAX_TEXT],
    )
    _log(onboarding, who, f"{'Verified' if passed else 'Needs attention:'} {item_id}")
    if save:
        store.save_onboarding(onboarding)


def reset_item(onboarding: Onboarding, item_id: str, who: str) -> None:
    """HarvTech clears a check (a grant was withdrawn, or a result was wrong)."""
    if item_id not in ITEM_BY_ID:
        raise NotAllowed("That item is not part of this onboarding.")
    onboarding.items[item_id] = ItemState()
    _log(onboarding, who, f"Reset {item_id}")
    store.save_onboarding(onboarding)


def import_preflight(onboarding: Onboarding, payload: dict, who: str) -> dict[str, int]:
    """Apply a `finops preflight` result file to a client's checklist.

    The file lists each checklist id with a status: "verified" marks the
    line verified; "failed" and "partial" mark it as needing attention,
    with the probe's own sentence as the detail; "not_checked" leaves the
    line alone, because the probe had nothing to say. Returns how many
    lines went each way.
    """
    if not isinstance(payload, dict) or payload.get("kind") != "finops-preflight":
        raise NotAllowed("That is not a finops preflight file.")
    results = payload.get("results")
    if not isinstance(results, list):
        raise NotAllowed("The preflight file has no results.")
    counts = {"verified": 0, "needs_attention": 0, "skipped": 0}
    label = f"HarvTech preflight ({who})"
    for row in results:
        item_id = str((row or {}).get("id") or "")
        status = str((row or {}).get("status") or "")
        item = ITEM_BY_ID.get(item_id)
        if item is None or item.tier not in onboarding.tiers or status == "not_checked":
            counts["skipped"] += 1
            continue
        passed = status == "verified"
        check_item(onboarding, item_id, passed, str(row.get("detail") or ""), label, save=False)
        counts["verified" if passed else "needs_attention"] += 1
    checked = str(payload.get("checked_at") or "")
    _log(
        onboarding,
        who,
        f"Imported preflight{' of ' + checked if checked else ''}: "
        f"{counts['verified']} verified, {counts['needs_attention']} need attention",
    )
    store.save_onboarding(onboarding)
    return counts


def update_request(
    request: ServiceRequest, status: str, response: str, who: str
) -> ServiceRequest:
    try:
        new_status = RequestStatus(status)
    except ValueError as exc:
        raise NotAllowed("Unknown request status.") from exc
    closing = new_status in (RequestStatus.DONE, RequestStatus.DECLINED)
    if closing and not response.strip():
        # The statement promises confirmation in writing; hold ourselves to it.
        raise NotAllowed("Closing a request needs a written response for the client.")
    request.status = new_status
    request.response = response.strip()[:MAX_TEXT]
    request.handled_by = who
    request.closed_at = _now() if closing else None
    store.save_request(request)
    return request


# ── Readiness: the numbers behind the dashboard ──────────────────────────────

def readiness(onboarding: Onboarding) -> dict:
    """Everything the dashboard draws, worked out from the checklist.

    Two percentages on purpose. `verified_pct` is what HarvTech has
    confirmed works; `claimed_pct` adds what the client says is done but
    nobody has checked. The gap between the two is HarvTech's to-do list.

    `rules_ready` is the figure a client cares about: how many of the
    health check's rules their grants have switched on so far. A tier
    counts once every one of its lines is verified; the optional extras
    count line by line.
    """
    in_scope = items_in_scope(onboarding)
    counts = {status: 0 for status in ItemStatus}
    for item in in_scope:
        counts[state_of(onboarding, item.id).status] += 1
    total = len(in_scope) or 1

    tiers = []
    rules_ready = rules_in_scope = 0
    for tier in TIERS:
        if tier.key not in onboarding.tiers:
            continue
        rows = [
            {"item": item, "state": state_of(onboarding, item.id)}
            for item in in_scope
            if item.tier == tier.key
        ]
        verified = sum(1 for r in rows if r["state"].status == ItemStatus.VERIFIED)
        done = sum(1 for r in rows if r["state"].status == ItemStatus.DONE)
        attention = sum(1 for r in rows if r["state"].status == ItemStatus.NEEDS_ATTENTION)
        if tier.per_item:
            tier_rules = sum(r["item"].rules for r in rows)
            tier_ready = sum(
                r["item"].rules for r in rows if r["state"].status == ItemStatus.VERIFIED
            )
        else:
            tier_rules = tier.rules
            tier_ready = tier.rules if rows and verified == len(rows) else 0
        rules_in_scope += tier_rules
        rules_ready += tier_ready
        if rows and verified == len(rows):
            state, label = "ready", "Verified"
        elif attention:
            state, label = "attention", "Needs attention"
        elif done:
            state, label = "waiting", "Waiting for HarvTech"
        elif verified:
            state, label = "progress", "In progress"
        else:
            state, label = "todo", "Not started"
        tiers.append(
            {
                "tier": tier,
                "rows": rows,
                "verified": verified,
                "done": done,
                "attention": attention,
                "total": len(rows),
                "verified_pct": round(verified / len(rows) * 100) if rows else 0,
                "claimed_pct": round((verified + done) / len(rows) * 100) if rows else 0,
                "rules": tier_rules,
                "rules_ready": tier_ready,
                "state": state,
                "label": label,
            }
        )

    verified = counts[ItemStatus.VERIFIED]
    claimed = verified + counts[ItemStatus.DONE]
    # Tier A verified is the bar for a first scan: everything else adds depth.
    tier_a = next((t for t in tiers if t["tier"].key == "A"), None)
    can_scan = bool(tier_a and tier_a["state"] == "ready")
    if verified == len(in_scope) and in_scope:
        headline = "Fully verified"
    elif can_scan:
        headline = "Ready for the first scan"
    elif counts[ItemStatus.NEEDS_ATTENTION]:
        headline = "Needs your attention"
    elif counts[ItemStatus.DONE]:
        headline = "Waiting for HarvTech to verify"
    elif claimed:
        headline = "In progress"
    else:
        headline = "Not started"
    return {
        "headline": headline,
        "can_scan": can_scan,
        "total": len(in_scope),
        "verified": verified,
        "done": counts[ItemStatus.DONE],
        "attention": counts[ItemStatus.NEEDS_ATTENTION],
        "todo": counts[ItemStatus.TODO],
        "verified_pct": round(verified / total * 100),
        "claimed_pct": round(claimed / total * 100),
        "rules_ready": rules_ready,
        "rules_in_scope": rules_in_scope,
        "rules_total": TOTAL_RULES,
        "tiers": tiers,
        "statement_ok": statement_current(onboarding),
    }


def waiting_on_harvtech(onboarding: Onboarding) -> list:
    """The lines a client has marked done that nobody has checked yet."""
    return [
        item
        for item in items_in_scope(onboarding)
        if state_of(onboarding, item.id).status == ItemStatus.DONE
    ]


def tier_name(key: str) -> str:
    tier = TIER_BY_KEY.get(key)
    return tier.name if tier else key
