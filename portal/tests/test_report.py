"""Published reports: HarvTech publishes, a client reads only their own, and visits are noted."""

import json

from app import store

from .conftest import ADMIN, DEMO_APPROVER, DEMO_TECH, OTHER_TECH

DEMO = "client-demo"
PDF = b"%PDF-1.7\n" + b"0" * 2000


def pack(customer: str = "Example Insurance", **over) -> dict:
    """A small report pack in the shape `finops publish-report` writes."""
    base = {
        "kind": "finops-report",
        "version": 1,
        "customer": customer,
        "currency": "GBP",
        "generated_at": "2026-11-20T11:00:00Z",
        "scan": {
            "finished_at": "2026-11-20T10:45:55Z",
            "source": "Azure, read-only",
            "resources": 341,
            "rules_ran": 333,
            "rules_not_assessed": 21,
        },
        "headline": {
            "monthly": 86257.62,
            "yearly": 1035091.44,
            "monthly_text": "£86,258",
            "yearly_text": "£1,035,091",
            "gross_monthly_text": "£123,495",
            "needs_change_window_text": "£10,361",
            "priced": 255,
            "unpriced": 124,
            "findings": 714,
        },
        "severity": [
            {"level": "critical", "label": "Critical", "count": 38},
            {"level": "high", "label": "High", "count": 118},
            {"level": "medium", "label": "Medium", "count": 87},
            {"level": "low", "label": "Low", "count": 67},
            {"level": "info", "label": "Info", "count": 25},
        ],
        "top_actions": [
            {"title": "Unlimited circuit sends 657 GB", "resource": "erc-london", "why": "saving", "figure": "£3,945.40 a month", "severity": None},
            {"title": "Windows Server 2012 R2 out of support", "resource": "dc-onprem-00", "why": "severity", "figure": "Critical", "severity": "critical"},
        ],
        "by_section": [
            {"name": "Licensing", "pillar": "cost", "findings": 93, "saving": 40871.44, "saving_text": "£40,871.44", "worst_severity": None, "worst_severity_label": ""},
            {"name": "Exposure", "pillar": "security", "findings": 60, "saving": None, "saving_text": "", "worst_severity": "critical", "worst_severity_label": "Critical"},
        ],
        "by_area": [],
        "assurance": {
            "note": "This view relates what the health check found to the control areas auditors examine.",
            "frameworks": [
                {
                    "key": "cyber_essentials",
                    "name": "NCSC Cyber Essentials",
                    "short": "Cyber Essentials",
                    "note": "The five technical controls.",
                    "assessed": 2,
                    "with_improvements": 1,
                    "none_found": 1,
                    "not_assessed": 0,
                    "outside": 0,
                    "controls": [
                        {"ref": "Firewalls", "title": "Firewalls", "status": "improvements", "result": "68 improvements found", "worst_severity": "critical", "looked_at": ["services reachable from the internet"], "outside": ""},
                        {"ref": "Malware protection", "title": "Malware protection", "status": "none_found", "result": "No improvements found", "worst_severity": None, "looked_at": ["endpoint protection"], "outside": ""},
                    ],
                }
            ],
        },
        "not_assessed": {"count": 21, "reasons": ["needs guest, not collected"]},
        "findings": [
            {
                "rule_id": "SEC-EXP-001", "title": "Management ports reachable from the internet", "resource": "vm-web-prd-01",
                "kind": "Virtual machine", "where": "rg-prod-app · Production", "pillar": "security", "section": "Exposure",
                "area": "Compute", "severity": "critical", "severity_label": "Critical", "severity_reasons": ["internet-facing"],
                "saving": None, "saving_text": "", "detail": "RDP is open to any address.", "remediation": "Restrict the rule.",
                "effort": "Low", "change_type": "Standard", "relates_to": "ISO 27001 A.8.20",
            }
        ],
        "findings_total": 714,
        "pdf": {"filename": "example-insurance-estate-review-2026-11-20.pdf"},
    }
    return {**base, **over}


def upload(browser, client_id: str = DEMO, body: dict | None = None, pdf: bytes | None = PDF, raw: bytes | None = None):
    files = {"pack": ("report.json", raw if raw is not None else json.dumps(body or pack()).encode(), "application/json")}
    if pdf is not None:
        files["pdf"] = ("report.pdf", pdf, "application/pdf")
    return browser.post(f"/admin/onboarding/{client_id}/report", files=files)


def test_before_anything_is_published(as_user):
    page = as_user(DEMO_TECH).get("/report")
    assert page.status_code == 200 and "No report has been published yet" in page.text
    assert "error=" in as_user(DEMO_TECH).get("/report/download").headers["location"]


def test_harvtech_publishes_and_the_client_reads_it(as_user):
    back = upload(as_user(ADMIN))
    assert "Published%20the%20report%20for%20%22Example%20Insurance%22" in back.headers["location"]
    saved = store.get_report(DEMO)
    assert saved.published_by == "alex@harvtech.example" and saved.pdf_bytes == len(PDF)

    page = as_user(DEMO_TECH).get("/report")
    assert page.status_code == 200
    for text in ("£86,258", "a month you could stop paying", "Last updated", "Download PDF",
                 "Unlimited circuit sends 657 GB", "68 improvements found", "No improvements found",
                 "Management ports reachable from the internet", "341 resources"):
        assert text in page.text, text
    assert "View as" not in page.text  # the staff preview banner is not for clients

    pdf = as_user(DEMO_TECH).get("/report/download")
    assert pdf.status_code == 200 and pdf.content == PDF
    assert pdf.headers["content-type"] == "application/pdf"
    assert "example-insurance-estate-review-2026-11-20.pdf" in pdf.headers["content-disposition"]
    assert pdf.headers["cache-control"] == "private, no-store"
    # The approver for the same client may read it too.
    assert "£86,258" in as_user(DEMO_APPROVER).get("/report").text


def test_another_client_never_sees_it(as_user):
    upload(as_user(ADMIN))
    other = as_user(OTHER_TECH)
    for url in ("/report", f"/report?client={DEMO}"):
        page = other.get(url)
        assert "£86,258" not in page.text and "No report has been published yet" in page.text
    for url in ("/report/download", f"/report/download?client={DEMO}"):
        answer = other.get(url)
        assert answer.status_code == 303 and answer.content != PDF
    # And nobody but HarvTech can publish or see activity.
    assert upload(other).status_code == 404
    assert upload(as_user(DEMO_TECH)).status_code == 404
    assert as_user(DEMO_TECH).get("/admin/activity").status_code == 404
    assert store.get_report("client-other") is None


def test_uploads_that_are_refused(as_user):
    admin = as_user(ADMIN)
    assert "not%20a%20finops%20report%20pack" in upload(admin, body={"kind": "something"}).headers["location"]
    assert "not%20valid%20JSON" in upload(admin, raw=b"{nope").headers["location"]
    assert "not%20a%20PDF" in upload(admin, pdf=b"<html>hello</html>").headers["location"]
    assert "version%209" in upload(admin, body=pack(version=9)).headers["location"]
    too_big = pack(findings=[{"detail": "x" * 2_000_000}])
    assert "too%20large" in upload(admin, body=too_big).headers["location"]
    missing = {k: v for k, v in pack().items() if k != "assurance"}
    assert "missing%3A%20assurance" in upload(admin, body=missing).headers["location"]
    assert store.get_report(DEMO) is None
    # A client with no onboarding has no page to publish to.
    assert "Open%20an%20onboarding" in upload(admin, client_id="client-nobody").headers["location"]


def test_republishing_without_a_pdf_keeps_the_one_already_there(as_user):
    admin = as_user(ADMIN)
    upload(admin)
    upload(admin, body=pack(generated_at="2026-11-27T09:00:00Z"), pdf=None)
    saved = store.get_report(DEMO)
    assert saved.pack["generated_at"] == "2026-11-27T09:00:00Z"
    assert saved.pdf_bytes == len(PDF) and store.get_report_pdf(DEMO) == PDF


def test_client_visits_are_recorded_and_staff_previews_are_not(as_user):
    admin = as_user(ADMIN)
    upload(admin)
    admin.get(f"/report?client={DEMO}")  # a staff preview
    admin.get(f"/report/download?client={DEMO}")
    assert store.list_activity(DEMO) == []

    tech = as_user(DEMO_TECH)
    tech.get("/onboarding")
    tech.get("/report")
    tech.get("/report")
    tech.get("/report/download")
    tech.get("/documents/security")
    events = store.list_activity(DEMO)
    assert [(e.kind, e.what) for e in reversed(events)] == [
        ("view", "Onboarding"),
        ("view", "Report"),
        ("view", "Report"),
        ("download", "example-insurance-estate-review-2026-11-20.pdf"),
        ("view", "Security statement"),
    ]
    assert {e.who for e in events} == {"priya@demo.example"}
    assert store.list_activity("client-other") == []

    client_page = admin.get(f"/admin/onboarding/{DEMO}").text
    assert "Opened 2 times by the client" in client_page and "PDF downloaded 1 time" in client_page
    assert "priya@demo.example" in client_page
    everything = admin.get("/admin/activity").text
    assert "Downloaded" in everything and "Viewed Report" in everything and "Example Insurance" in everything


def test_the_statement_tells_clients_their_visits_are_recorded(as_user):
    text = as_user(DEMO_TECH).get("/documents/security").text
    assert "records when your" in text and "does not record what is typed" in text
