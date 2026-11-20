"""
Client onboarding pages — the checklist, the readiness dashboard, the
documents, data-handling requests, and HarvTech's admin pages over them.

Two audiences, one router:

  Client pages  /onboarding  /documents/...  /requests
      A client user sees and changes ONLY their own client's onboarding.
      The client id never comes from the URL or a form for them — it
      comes from their signed-in session, so there is nothing to tamper
      with. (Staff may add ?client=<id> to see a client's page as they do.)

  Admin pages   /admin/onboarding  /admin/requests
      HarvTech staff only (`require_staff`). This is where a client's
      "done" becomes "verified", and where requests are answered.

Forms are plain HTML posts read with FastAPI's Form(...), then a 303
redirect back to the page (Post/Redirect/Get, as in web.py). The session
cookie is SameSite=Lax, so a form on another site cannot post here with
a signed-in user's cookie.
"""

import json
from pathlib import Path
from urllib.parse import quote

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates

from . import access, activity, onboarding_services as rules, store
from .auth import require_user
from .models import ItemStatus, RequestStatus
from .notify import notify
from .onboarding_catalogue import ITEM_BY_ID, TIERS, TOTAL_RULES
from .web import nav_for

router = APIRouter(tags=["onboarding"])
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")

def _when(value) -> str:
    """'3 Nov 2026' from a datetime; used in templates as {{ some_date|when }}."""
    return f"{value.day} {value:%b %Y}" if value else ""


def _when_time(value) -> str:
    """'3 Nov 2026, 14:05' — for activity, where the time of day matters."""
    return f"{value.day} {value:%b %Y, %H:%M}" if value else ""


def _iso_when(value) -> str:
    """'20 Nov 2026' from the ISO timestamps a report pack carries."""
    from datetime import datetime

    try:
        return _when(datetime.fromisoformat(str(value).replace("Z", "+00:00")))
    except ValueError:
        return str(value or "")


templates.env.filters["when"] = _when
templates.env.filters["when_time"] = _when_time
templates.env.filters["iso_when"] = _iso_when

# The readiness ring is an SVG circle of this radius; its circumference is
# what the stroke-dasharray arithmetic in the template needs.
RING_RADIUS = 54
RING_LENGTH = 2 * 3.14159265 * RING_RADIUS


def who_is(user: dict | None) -> str:
    """A name for the audit trail."""
    if user is None:
        return "HarvTech (local)"
    return user.get("email") or user.get("name") or user.get("oid") or "unknown"


def require_staff(user: dict | None = Depends(require_user)) -> dict | None:
    """Gate for the admin pages. 404, not 403: a client has no reason to
    learn that an admin area exists."""
    if not access.is_staff(user):
        raise HTTPException(status_code=404, detail="Not found")
    return user


def _client_id_for(request: Request, user: dict | None) -> str | None:
    """Which client's onboarding this request is about.

    A client user: always their own, whatever the URL says. Staff: the
    one named in ?client=, so they can open any client's page.
    """
    if access.is_staff(user):
        return request.query_params.get("client") or None
    if not access.can_see_onboarding(user):
        return None
    return access.client_of(user)


def _back(path: str, message: str = "", *, error: bool = False) -> RedirectResponse:
    """Redirect back to a page, optionally with a message to show on it."""
    if message:
        joiner = "&" if "?" in path else "?"
        path = f"{path}{joiner}{'error' if error else 'notice'}={quote(message)}"
    return RedirectResponse(path, status_code=303)


def _suffix(request: Request, user: dict | None) -> str:
    """Keeps a staff member's ?client= on links and forms while they view as a client."""
    client = request.query_params.get("client")
    return f"?client={quote(client)}" if client and access.is_staff(user) else ""


def _page(request: Request, user: dict | None, template: str, active: str, **context):
    return templates.TemplateResponse(
        request,
        template,
        {
            "user": user,
            "nav": nav_for(user),
            "active": active,
            "notice": request.query_params.get("notice"),
            "error": request.query_params.get("error"),
            "suffix": _suffix(request, user),
            "is_staff": access.is_staff(user),
            **context,
        },
    )


# ── Client pages ─────────────────────────────────────────────────────────────

@router.get("/onboarding")
def onboarding_dashboard(request: Request, user: dict | None = Depends(require_user)):
    """The client's readiness dashboard and checklist."""
    client_id = _client_id_for(request, user)
    if client_id is None:
        # Staff with no ?client= belong on the admin list; anyone else has
        # no onboarding to see.
        return RedirectResponse("/admin/onboarding" if access.is_staff(user) else "/", 303)
    onboarding = store.get_onboarding(client_id)
    if onboarding is None:
        return _page(request, user, "onboarding_none.html", "Onboarding")
    ready = rules.readiness(onboarding)
    activity.record(user, activity.VIEW, "Onboarding")
    return _page(
        request,
        user,
        "onboarding.html",
        "Onboarding",
        onboarding=onboarding,
        ready=ready,
        ring={
            "radius": RING_RADIUS,
            "length": round(RING_LENGTH, 2),
            "verified": round(RING_LENGTH * ready["verified_pct"] / 100, 2),
            "claimed": round(RING_LENGTH * ready["claimed_pct"] / 100, 2),
        },
        open_requests=[
            r
            for r in store.list_requests(client_id)
            if r.status in (RequestStatus.OPEN, RequestStatus.IN_PROGRESS)
        ],
        history=list(reversed(onboarding.history))[:8],
        ItemStatus=ItemStatus,
    )


@router.post("/onboarding/items/{item_id}/{action}")
def onboarding_item_action(
    request: Request, item_id: str, action: str, user: dict | None = Depends(require_user)
):
    """A client marks a line done, or reopens one they marked by mistake."""
    client_id = _client_id_for(request, user)
    onboarding = store.get_onboarding(client_id) if client_id else None
    back = f"/onboarding{_suffix(request, user)}"
    if onboarding is None or action not in ("done", "undo"):
        return _back(back)
    try:
        if action == "done":
            rules.mark_done(onboarding, item_id, who_is(user))
            item = ITEM_BY_ID[item_id]
            notify(
                "item_done",
                onboarding.client_name,
                who_is(user),
                f"marked {item_id} as done ({item.title}); ready to verify",
                f"/admin/onboarding/{onboarding.client_id}",
            )
        else:
            rules.undo_done(onboarding, item_id, who_is(user))
    except rules.NotAllowed as exc:
        return _back(back, str(exc), error=True)
    return _back(f"{back}#item-{item_id}")


@router.get("/documents/onboarding")
def document_onboarding(request: Request, user: dict | None = Depends(require_user)):
    """The onboarding guide, generated from the same catalogue as the checklist."""
    if not access.can_see_onboarding(user):
        return RedirectResponse("/", 303)
    activity.record(user, activity.VIEW, "Onboarding guide")
    return _page(
        request,
        user,
        "document_onboarding.html",
        "Onboarding",
        tiers=[{"tier": t, "items": [i for i in ITEM_BY_ID.values() if i.tier == t.key]} for t in TIERS],
        total_rules=TOTAL_RULES,
    )


@router.get("/documents/security")
def document_security(request: Request, user: dict | None = Depends(require_user)):
    """The security and data-handling statement, with the client's acceptance."""
    if not access.can_see_onboarding(user):
        return RedirectResponse("/", 303)
    client_id = _client_id_for(request, user)
    onboarding = store.get_onboarding(client_id) if client_id else None
    activity.record(user, activity.VIEW, "Security statement")
    return _page(
        request,
        user,
        "document_security.html",
        "Security",
        onboarding=onboarding,
        accepted=bool(onboarding and rules.statement_current(onboarding)),
        version=rules.STATEMENT_VERSION,
    )


@router.post("/documents/security/acknowledge")
def acknowledge_security(request: Request, user: dict | None = Depends(require_user)):
    client_id = _client_id_for(request, user)
    onboarding = store.get_onboarding(client_id) if client_id else None
    back = f"/documents/security{_suffix(request, user)}"
    if onboarding is None:
        return _back(back)
    rules.acknowledge_statement(onboarding, who_is(user))
    notify(
        "statement_acknowledged",
        onboarding.client_name,
        who_is(user),
        f"accepted the security and data-handling statement (version {rules.STATEMENT_VERSION})",
        f"/admin/onboarding/{onboarding.client_id}",
    )
    return _back(back, "Thank you. Your acceptance is recorded.")


@router.get("/requests")
def requests_page(request: Request, user: dict | None = Depends(require_user)):
    """A client's data-handling requests: raise one, and see the answers."""
    client_id = _client_id_for(request, user)
    if client_id is None:
        return RedirectResponse("/admin/onboarding" if access.is_staff(user) else "/", 303)
    onboarding = store.get_onboarding(client_id)
    requests = sorted(
        store.list_requests(client_id), key=lambda r: str(r.raised_at or ""), reverse=True
    )
    return _page(
        request,
        user,
        "requests.html",
        "Requests",
        onboarding=onboarding,
        requests=requests,
        kinds=rules.REQUEST_KINDS,
    )


@router.post("/requests")
def raise_request(
    request: Request,
    kind: str = Form(""),
    detail: str = Form(""),
    user: dict | None = Depends(require_user),
):
    client_id = _client_id_for(request, user)
    back = f"/requests{_suffix(request, user)}"
    if client_id is None:
        return _back("/")
    onboarding = store.get_onboarding(client_id)
    try:
        raised = rules.raise_request(client_id, kind, detail, who_is(user))
    except rules.NotAllowed as exc:
        return _back(back, str(exc), error=True)
    notify(
        "request_raised",
        onboarding.client_name if onboarding else client_id,
        who_is(user),
        f"raised a request: {rules.REQUEST_KINDS[kind]['label']}",
        f"/admin/requests#{raised.id}",
    )
    return _back(back, "Your request has been sent to HarvTech. The answer will appear here.")


# ── HarvTech admin pages ─────────────────────────────────────────────────────

@router.get("/admin/onboarding")
def admin_onboarding(request: Request, user: dict | None = Depends(require_staff)):
    """Every client's readiness on one page, and what is waiting on HarvTech."""
    clients = []
    for onboarding in sorted(store.list_onboardings(), key=lambda o: o.client_name.lower()):
        clients.append(
            {
                "onboarding": onboarding,
                "ready": rules.readiness(onboarding),
                "waiting": rules.waiting_on_harvtech(onboarding),
            }
        )
    open_requests = [
        r
        for r in store.list_requests(None)
        if r.status in (RequestStatus.OPEN, RequestStatus.IN_PROGRESS)
    ]
    return _page(
        request,
        user,
        "admin_onboarding.html",
        "Onboarding",
        clients=clients,
        open_requests=open_requests,
        tiers=TIERS,
        default_tiers=("A", "B", "C", "D", "X"),
    )


@router.post("/admin/onboarding")
def admin_start_onboarding(
    client_id: str = Form(""),
    client_name: str = Form(""),
    tiers: list[str] = Form(default=[]),
    user: dict | None = Depends(require_staff),
):
    try:
        onboarding = rules.start(client_id, client_name, tiers, who_is(user))
    except rules.NotAllowed as exc:
        return _back("/admin/onboarding", str(exc), error=True)
    return _back(f"/admin/onboarding/{quote(onboarding.client_id)}", "Onboarding opened.")


@router.get("/admin/onboarding/{client_id}")
def admin_client(request: Request, client_id: str, user: dict | None = Depends(require_staff)):
    """One client's checklist, with the controls to verify each line."""
    onboarding = store.get_onboarding(client_id)
    if onboarding is None:
        return _back("/admin/onboarding", "No onboarding for that client.", error=True)
    return _page(
        request,
        user,
        "admin_client.html",
        "Onboarding",
        onboarding=onboarding,
        ready=rules.readiness(onboarding),
        requests=sorted(
            store.list_requests(client_id), key=lambda r: str(r.raised_at or ""), reverse=True
        ),
        kinds=rules.REQUEST_KINDS,
        history=list(reversed(onboarding.history))[:30],
        ItemStatus=ItemStatus,
        report=store.get_report(client_id),
        activity=activity.summary(client_id),
    )


@router.post("/admin/onboarding/{client_id}/items/{item_id}")
def admin_check_item(
    client_id: str,
    item_id: str,
    result: str = Form(""),
    detail: str = Form(""),
    user: dict | None = Depends(require_staff),
):
    """Record a check: verified, needs attention, or reset."""
    onboarding = store.get_onboarding(client_id)
    back = f"/admin/onboarding/{quote(client_id)}"
    if onboarding is None:
        return _back("/admin/onboarding")
    try:
        if result == "reset":
            rules.reset_item(onboarding, item_id, who_is(user))
        elif result in ("verified", "needs_attention"):
            rules.check_item(onboarding, item_id, result == "verified", detail, who_is(user))
        else:
            raise rules.NotAllowed("Choose verified, needs attention or reset.")
    except rules.NotAllowed as exc:
        return _back(back, str(exc), error=True)
    return _back(f"{back}#item-{item_id}")


@router.post("/admin/onboarding/{client_id}/preflight")
def admin_import_preflight(
    client_id: str, payload: str = Form(""), user: dict | None = Depends(require_staff)
):
    """Paste the JSON `finops preflight --out` wrote; apply it to the checklist."""
    onboarding = store.get_onboarding(client_id)
    back = f"/admin/onboarding/{quote(client_id)}"
    if onboarding is None:
        return _back("/admin/onboarding")
    try:
        parsed = json.loads(payload)
    except ValueError:
        return _back(back, "That is not valid JSON.", error=True)
    try:
        counts = rules.import_preflight(onboarding, parsed, who_is(user))
    except rules.NotAllowed as exc:
        return _back(back, str(exc), error=True)
    return _back(
        back,
        f"Preflight applied: {counts['verified']} verified, "
        f"{counts['needs_attention']} need attention, {counts['skipped']} left alone.",
    )


@router.get("/admin/requests")
def admin_requests(request: Request, user: dict | None = Depends(require_staff)):
    """Every client's requests, open ones first."""
    names = {o.client_id: o.client_name for o in store.list_onboardings()}
    order = {RequestStatus.OPEN: 0, RequestStatus.IN_PROGRESS: 1}
    requests = sorted(
        store.list_requests(None),
        key=lambda r: (order.get(r.status, 2), -(r.raised_at.timestamp() if r.raised_at else 0)),
    )
    return _page(
        request,
        user,
        "admin_requests.html",
        "Onboarding",
        requests=requests,
        names=names,
        kinds=rules.REQUEST_KINDS,
        statuses=list(RequestStatus),
    )


@router.post("/admin/requests/{request_id}")
def admin_update_request(
    request_id: str,
    status: str = Form(""),
    response: str = Form(""),
    user: dict | None = Depends(require_staff),
):
    found = store.get_request(request_id)
    if found is None:
        return _back("/admin/requests", "No such request.", error=True)
    try:
        rules.update_request(found, status, response, who_is(user))
    except rules.NotAllowed as exc:
        return _back(f"/admin/requests#{request_id}", str(exc), error=True)
    return _back("/admin/requests", "Request updated.")
