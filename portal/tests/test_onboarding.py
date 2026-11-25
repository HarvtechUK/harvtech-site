"""The onboarding checklist: the client says done, only HarvTech verifies."""

import json

from app import onboarding_services as rules
from app import store
from app.models import ItemStatus, RequestStatus

from .conftest import ADMIN, CONTRACTOR, DEMO_APPROVER, DEMO_TECH, FIRST_APPROVER, OTHER_TECH

DEMO = "client-demo"


def status(item_id: str) -> ItemStatus:
    return rules.state_of(store.get_onboarding(DEMO), item_id).status


def test_readiness_counts_what_is_verified_not_what_is_claimed():
    ready = rules.readiness(store.get_onboarding(DEMO))
    assert (ready["verified"], ready["done"], ready["attention"], ready["todo"]) == (4, 4, 1, 8)
    assert ready["total"] == 17 and ready["verified_pct"] == 24 and ready["claimed_pct"] == 47
    # Tier A is verified, so its 305 checks are unlocked; C is only part verified, so none of its 8.
    assert ready["rules_ready"] == 305 and ready["rules_in_scope"] == 354
    assert ready["can_scan"] and ready["headline"] == "Ready for the first scan"
    by_tier = {t["tier"].key: t for t in ready["tiers"]}
    assert by_tier["A"]["state"] == "ready" and by_tier["B"]["state"] == "attention"
    assert by_tier["C"]["state"] == "waiting" and by_tier["E"]["state"] == "todo"


def test_the_client_dashboard_renders_and_is_only_theirs(as_user):
    page = as_user(DEMO_TECH).get("/onboarding")
    assert page.status_code == 200
    assert "Example Insurance" in page.text and "Ready for the first scan" in page.text
    assert "law-sentinel" in page.text  # the probe's own words reach the client
    # ?client= is ignored for a client user: they get their own, never another's.
    theirs = as_user(OTHER_TECH).get(f"/onboarding?client={DEMO}")
    assert "Example Insurance" not in theirs.text and "Nothing to do yet" in theirs.text
    # An approver for the same client sees it too; another client's approver does not.
    assert "Example Insurance" in as_user(DEMO_APPROVER).get("/onboarding").text
    assert "Example Insurance" not in as_user(FIRST_APPROVER).get("/onboarding").text


def test_a_client_marks_done_and_cannot_verify_their_own_work(as_user):
    tech = as_user(DEMO_TECH)
    assert status("C5") == ItemStatus.TODO
    assert tech.post("/onboarding/items/C5/done").status_code == 303
    assert status("C5") == ItemStatus.DONE
    assert rules.state_of(store.get_onboarding(DEMO), "C5").done_by == "priya@demo.example"
    # Reopen it, then mark it again.
    tech.post("/onboarding/items/C5/undo")
    assert status("C5") == ItemStatus.TODO
    # A verified item cannot be changed by the client.
    assert "already%20verified" in tech.post("/onboarding/items/A1/done").headers["location"]
    assert status("A1") == ItemStatus.VERIFIED
    # The admin pages do not exist for a client, and their posts change nothing.
    assert tech.get("/admin/onboarding").status_code == 404
    assert tech.get(f"/admin/onboarding/{DEMO}").status_code == 404
    assert tech.post(f"/admin/onboarding/{DEMO}/items/C5", data={"result": "verified"}).status_code == 404
    assert tech.post(f"/admin/onboarding/{DEMO}/preflight", data={"payload": "{}"}).status_code == 404
    assert status("C5") == ItemStatus.TODO


def test_another_client_cannot_touch_this_checklist(as_user):
    other = as_user(OTHER_TECH)
    other.post("/onboarding/items/C5/done")
    other.post(f"/onboarding/items/C5/done?client={DEMO}")
    assert status("C5") == ItemStatus.TODO


def test_harvtech_verifies_bounces_and_resets(as_user):
    admin = as_user(ADMIN)
    admin.post(f"/admin/onboarding/{DEMO}/items/C2", data={"result": "verified", "detail": "Roles read"})
    state = rules.state_of(store.get_onboarding(DEMO), "C2")
    assert state.status == ItemStatus.VERIFIED and state.detail == "Roles read"
    assert state.done_by == "priya.shah@example-insurance.co.uk"  # the client's part is kept
    admin.post(f"/admin/onboarding/{DEMO}/items/C3", data={"result": "needs_attention", "detail": "403"})
    assert status("C3") == ItemStatus.NEEDS_ATTENTION
    # The client fixes it and says so; it waits for a re-check.
    as_user(DEMO_TECH).post("/onboarding/items/C3/done")
    assert status("C3") == ItemStatus.DONE
    as_user(CONTRACTOR).post(f"/admin/onboarding/{DEMO}/items/C3", data={"result": "reset"})
    assert status("C3") == ItemStatus.TODO


def test_importing_a_preflight_file(as_user):
    payload = {
        "kind": "finops-preflight",
        "checked_at": "2026-11-20T09:00:00Z",
        "results": [
            {"id": "B1", "status": "verified", "detail": "3 of 3 workspaces answered"},
            {"id": "C2", "status": "partial", "detail": "Refused: PIM assignment schedules"},
            {"id": "D1", "status": "failed", "detail": "The reservations list was refused (HTTP 403)"},
            {"id": "E2", "status": "not_checked", "detail": "No pack imported yet"},
            {"id": "ZZ", "status": "verified", "detail": "an id this portal does not know"},
        ],
    }
    back = as_user(ADMIN).post(f"/admin/onboarding/{DEMO}/preflight", data={"payload": json.dumps(payload)})
    assert "1%20verified%2C%202%20need%20attention%2C%202%20left%20alone" in back.headers["location"]
    assert status("B1") == ItemStatus.VERIFIED
    assert status("C2") == ItemStatus.NEEDS_ATTENTION and status("D1") == ItemStatus.NEEDS_ATTENTION
    assert rules.state_of(store.get_onboarding(DEMO), "C2").detail == "Refused: PIM assignment schedules"
    assert status("E2") == ItemStatus.TODO
    # Tier B is now verified: its 13 checks are unlocked.
    assert rules.readiness(store.get_onboarding(DEMO))["rules_ready"] == 318
    bad = as_user(ADMIN).post(f"/admin/onboarding/{DEMO}/preflight", data={"payload": '{"kind": "x"}'})
    assert "not%20a%20finops%20preflight%20file" in bad.headers["location"]
    assert "not%20valid%20JSON" in as_user(ADMIN).post(
        f"/admin/onboarding/{DEMO}/preflight", data={"payload": "nope"}
    ).headers["location"]


def test_opening_an_onboarding(as_user):
    admin = as_user(ADMIN)
    made = admin.post(
        "/admin/onboarding", data={"client_id": "client-other", "client_name": "Other Mutual", "tiers": ["B"]}
    )
    assert made.headers["location"].startswith("/admin/onboarding/client-other")
    opened = store.get_onboarding("client-other")
    # Reader and the context conversations are always part of an engagement.
    assert opened.tiers == ["A", "B", "X"] and opened.client_name == "Other Mutual"
    assert rules.readiness(opened)["headline"] == "Not started"
    assert "Other Mutual" in as_user(OTHER_TECH).get("/onboarding").text
    again = admin.post("/admin/onboarding", data={"client_id": "client-other", "client_name": "Again"})
    assert "already%20has" in again.headers["location"]
    # An item outside the engagement's tiers cannot be marked.
    assert "not%20part" in as_user(OTHER_TECH).post("/onboarding/items/D1/done").headers["location"]


def test_accepting_the_statement(as_user):
    admin = as_user(ADMIN)
    admin.post("/admin/onboarding", data={"client_id": "client-other", "client_name": "Other Mutual"})
    tech = as_user(OTHER_TECH)
    assert "We have read and accept" in tech.get("/documents/security").text
    assert "read and accept the security" in tech.get("/onboarding").text
    tech.post("/documents/security/acknowledge")
    record = store.get_onboarding("client-other")
    assert record.statement_acknowledged_by == "eng@other.example" and rules.statement_current(record)
    assert "Accepted for Other Mutual" in tech.get("/documents/security").text
    assert "Onboarding guide" in tech.get("/documents/onboarding").text


def test_requests_go_to_harvtech_and_come_back_answered(as_user, monkeypatch):
    sent = []
    monkeypatch.setattr("app.onboarding_web.notify", lambda *a, **k: sent.append(a))
    tech = as_user(DEMO_TECH)
    tech.post("/requests", data={"kind": "delete_data", "detail": "End of engagement"})
    assert sent and sent[0][0] == "request_raised" and sent[0][1] == "Example Insurance"
    mine = [r for r in store.list_requests(DEMO) if r.kind == "delete_data"]
    assert len(mine) == 1 and mine[0].status == RequestStatus.OPEN and mine[0].raised_by == "priya@demo.example"
    assert "Choose%20one" in tech.post("/requests", data={"kind": "nonsense"}).headers["location"]

    # Another client sees none of it, and cannot reach the admin queue.
    other = as_user(OTHER_TECH)
    assert "End of engagement" not in other.get("/requests").text
    assert other.get("/admin/requests").status_code == 404
    assert other.post(f"/admin/requests/{mine[0].id}", data={"status": "done", "response": "x"}).status_code == 404

    admin = as_user(ADMIN)
    assert "End of engagement" in admin.get("/admin/requests").text
    # Closing needs a written response.
    refused = admin.post(f"/admin/requests/{mine[0].id}", data={"status": "done", "response": " "})
    assert "written%20response" in refused.headers["location"]
    admin.post(
        f"/admin/requests/{mine[0].id}",
        data={"status": "done", "response": "Deleted on 20 November: 4 scans, 2,911 findings."},
    )
    closed = store.get_request(mine[0].id)
    assert closed.status == RequestStatus.DONE and closed.closed_at is not None
    assert "Deleted on 20 November" in tech.get("/requests").text


def test_marking_done_notifies_harvtech(as_user, monkeypatch):
    sent = []
    monkeypatch.setattr("app.onboarding_web.notify", lambda *a, **k: sent.append(a))
    as_user(DEMO_TECH).post("/onboarding/items/D2/done")
    assert sent[0][0] == "item_done" and "D2" in sent[0][3]
    assert sent[0][4] == f"/admin/onboarding/{DEMO}"


def test_the_checklist_ids_match_the_scanning_engine():
    """The contract with `finops preflight`: same ids, same order."""
    from app.onboarding_catalogue import ITEMS, TOTAL_RULES

    assert [i.id for i in ITEMS] == [
        "A1", "A2", "B1", "C1", "C2", "C3", "C4", "C5", "D1", "D2",
        "E1", "E2", "E3", "E4", "E5", "X1", "X2",
    ]
    assert TOTAL_RULES == 354
