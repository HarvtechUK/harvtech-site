"""
Published reports — the rules for accepting one, and the numbers the page draws.

A report reaches the portal as two files HarvTech uploads on a client's
admin page: `report.json` (the pack `finops publish-report` writes in the
harvtech-finops repository) and `report.pdf`. Nothing is taken on trust:
the pack must say it is a finops report, be a version this portal
understands, and fit in a Cosmos document; the PDF must actually be a PDF.

The customer name inside the pack is shown back to the admin before and
after publishing, because the one mistake that matters here is publishing
client A's report on client B's page.
"""

import json
from datetime import UTC, datetime

from . import store
from .models import Report

PACK_KIND = "finops-report"
PACK_VERSIONS = {1}
# A Cosmos document cannot exceed 2 MB; stay well inside it.
MAX_PACK_BYTES = 1_500_000
MAX_PDF_BYTES = 40_000_000
REQUIRED_KEYS = ("customer", "generated_at", "scan", "headline", "severity", "assurance", "findings")


class NotAllowed(Exception):
    """An upload the rules refuse — the route shows the message to the admin."""


def parse_pack(raw: bytes) -> dict:
    """The pack from an uploaded report.json, or NotAllowed saying what is wrong."""
    if not raw:
        raise NotAllowed("Choose the report.json file.")
    if len(raw) > MAX_PACK_BYTES:
        raise NotAllowed(
            "report.json is too large for the portal. Publish with a smaller --findings number; "
            "the PDF still carries every finding."
        )
    try:
        pack = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise NotAllowed("report.json is not valid JSON.") from exc
    if not isinstance(pack, dict) or pack.get("kind") != PACK_KIND:
        raise NotAllowed("That file is not a finops report pack.")
    if pack.get("version") not in PACK_VERSIONS:
        raise NotAllowed(f"Report pack version {pack.get('version')} is not one this portal understands.")
    missing = [key for key in REQUIRED_KEYS if key not in pack]
    if missing:
        raise NotAllowed(f"The report pack is missing: {', '.join(missing)}.")
    return pack


def check_pdf(raw: bytes) -> None:
    if not raw:
        return  # a report may be published without a PDF; the page then offers no download
    if len(raw) > MAX_PDF_BYTES:
        raise NotAllowed("The PDF is larger than the portal accepts.")
    if not raw.startswith(b"%PDF-"):
        raise NotAllowed("The second file is not a PDF.")


def publish(client_id: str, pack_raw: bytes, pdf_raw: bytes, who: str) -> Report:
    """Validate both files, then store the PDF and the report (in that order,
    so a report never points at a PDF that failed to save)."""
    pack = parse_pack(pack_raw)
    check_pdf(pdf_raw)
    if pdf_raw:
        store.save_report_pdf(client_id, pdf_raw)
    previous = store.get_report(client_id)
    report = Report(
        id=client_id,
        client_id=client_id,
        pack=pack,
        published_at=datetime.now(UTC),
        published_by=who,
        # No new PDF this time: keep pointing at the one already stored.
        pdf_filename=(
            str((pack.get("pdf") or {}).get("filename") or "report.pdf")
            if pdf_raw
            else (previous.pdf_filename if previous else "")
        ),
        pdf_bytes=len(pdf_raw) if pdf_raw else (previous.pdf_bytes if previous else 0),
    )
    store.save_report(report)
    return report


def view(report: Report) -> dict:
    """The few numbers the page works out from the pack: bar widths and totals.

    Everything else the template prints straight from the pack, which
    already carries the client's words and formatted figures.
    """
    pack = report.pack
    severity = [s for s in pack.get("severity", []) if s.get("level") != "info"]
    total = sum(int(s.get("count") or 0) for s in severity) or 1
    sections = pack.get("by_section", [])
    cost = [s for s in sections if s.get("saving")]
    biggest = max((float(s["saving"]) for s in cost), default=0.0) or 1.0
    return {
        "severity": [
            {**s, "pct": round(int(s.get("count") or 0) / total * 100, 1)} for s in severity
        ],
        "security_total": sum(int(s.get("count") or 0) for s in severity),
        "cost_sections": [
            {**s, "pct": max(2, round(float(s["saving"]) / biggest * 100))} for s in cost
        ],
        "risk_sections": [s for s in sections if not s.get("saving") and s.get("worst_severity")],
        "findings_shown": len(pack.get("findings", [])),
    }
