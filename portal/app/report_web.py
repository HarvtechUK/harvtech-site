"""
The client's report page, its PDF download, and HarvTech's publishing pages.

  Client   /report            the published health-check report as a page
           /report/download   the same report as a PDF

  Admin    /admin/onboarding/{client}/report   publish (upload the two files)
           /admin/activity                     who has signed in and opened what

The report is a snapshot HarvTech publishes, not a live view of the
scanning engine: the engine's database is never reachable from here. A
client user's client id comes from their session, exactly as on the
onboarding pages, so the only report they can ever be served is their own.

Each view and each download by a client user is recorded (activity.py).
"""

from urllib.parse import quote

from fastapi import APIRouter, Depends, File, Request, UploadFile
from fastapi.responses import RedirectResponse, Response

from . import access, activity, reports, store
from .auth import require_user
from .onboarding_web import _back, _client_id_for, _page, require_staff, who_is

router = APIRouter(tags=["report"])


def _size(n: int) -> str:
    """'1.2 MB' for a byte count."""
    return f"{n / 1_000_000:.1f} MB" if n >= 100_000 else f"{max(1, round(n / 1000))} KB"


@router.get("/report")
def report_page(request: Request, user: dict | None = Depends(require_user)):
    """The client's published report."""
    client_id = _client_id_for(request, user)
    if client_id is None:
        return RedirectResponse("/admin/onboarding" if access.is_staff(user) else "/", 303)
    report = store.get_report(client_id)
    onboarding = store.get_onboarding(client_id)
    name = onboarding.client_name if onboarding else (report.pack.get("customer") if report else "")
    if report is None:
        return _page(request, user, "report_none.html", "Report", client_name=name)
    activity.record(user, activity.VIEW, "Report")
    return _page(
        request,
        user,
        "report.html",
        "Report",
        report=report,
        pack=report.pack,
        view=reports.view(report),
        client_name=name,
        pdf_size=_size(report.pdf_bytes) if report.pdf_bytes else "",
    )


@router.get("/report/download")
def report_download(request: Request, user: dict | None = Depends(require_user)):
    """The report PDF, for the signed-in user's own client only."""
    client_id = _client_id_for(request, user)
    report = store.get_report(client_id) if client_id else None
    content = store.get_report_pdf(client_id) if report and report.pdf_bytes else None
    if content is None:
        return _back("/report", "There is no PDF to download yet.", error=True)
    activity.record(user, activity.DOWNLOAD, report.pdf_filename or "report.pdf")
    filename = (report.pdf_filename or "report.pdf").replace('"', "")
    return Response(
        content,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            # A client's report must never sit in a shared cache.
            "Cache-Control": "private, no-store",
        },
    )


# ── HarvTech admin ───────────────────────────────────────────────────────────

@router.post("/admin/onboarding/{client_id}/report")
async def admin_publish_report(
    client_id: str,
    pack: UploadFile = File(...),
    pdf: UploadFile | None = File(None),
    user: dict | None = Depends(require_staff),
):
    """Publish a report for a client: report.json, and report.pdf beside it.

    `UploadFile` is how FastAPI hands over a file from a form. Reading it
    is asynchronous (`await`), which is why this one route is `async def`.
    """
    back = f"/admin/onboarding/{quote(client_id)}"
    if store.get_onboarding(client_id) is None:
        return _back("/admin/onboarding", "Open an onboarding for that client first.", error=True)
    pack_raw = await pack.read()
    pdf_raw = await pdf.read() if pdf is not None else b""
    try:
        published = reports.publish(client_id, pack_raw, pdf_raw, who_is(user))
    except reports.NotAllowed as exc:
        return _back(back, str(exc), error=True)
    return _back(
        back,
        f"Published the report for \"{published.pack.get('customer')}\" to this client"
        + (" with its PDF." if pdf_raw else " (no new PDF)."),
    )


@router.get("/admin/activity")
def admin_activity(request: Request, user: dict | None = Depends(require_staff)):
    """Every client's recent activity, newest first."""
    names = {o.client_id: o.client_name for o in store.list_onboardings()}
    return _page(
        request,
        user,
        "admin_activity.html",
        "Activity",
        events=store.list_activity(None, limit=300),
        names=names,
    )
