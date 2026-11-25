"""Client isolation on the pages and API that existed before onboarding."""

from app import access

from .conftest import ADMIN, CONTRACTOR, DEMO_APPROVER, DEMO_TECH, FIRST_APPROVER, ORPHAN

TIMESHEET = "ts-2026-06-client-first"
ENGAGEMENT = "eng-2026-001"


def test_the_rules_themselves():
    assert access.can_see_client(None, "anyone")  # local open mode is staff
    assert access.can_see_client(ADMIN, "client-first") and access.can_see_client(CONTRACTOR, "client-first")
    assert access.can_see_client(FIRST_APPROVER, "client-first")
    assert not access.can_see_client(DEMO_APPROVER, "client-first")
    assert not access.can_see_client(ORPHAN, "client-first") and not access.can_see_client(ORPHAN, None)
    assert not access.can_see_client({"role": "something-new", "client_id": "client-first"}, "client-first")
    assert not access.can_see_timesheets(DEMO_TECH) and access.can_see_onboarding(DEMO_TECH)
    # HarvTech submits; the client decides; a contractor never approves their own work.
    assert access.can_change_timesheet(CONTRACTOR, "submit", "client-first")
    assert not access.can_change_timesheet(CONTRACTOR, "approve", "client-first")
    assert access.can_change_timesheet(FIRST_APPROVER, "approve", "client-first")
    assert not access.can_change_timesheet(FIRST_APPROVER, "submit", "client-first")
    assert not access.can_change_timesheet(DEMO_APPROVER, "approve", "client-first")


def test_a_client_sees_only_its_own_timesheets(as_user):
    own = as_user(FIRST_APPROVER)
    assert [t["id"] for t in own.get("/api/timesheets").json()] == [TIMESHEET]
    assert "Azure landing zone" in own.get("/").text

    other = as_user(DEMO_APPROVER)
    assert other.get("/api/timesheets").json() == []
    assert other.get("/api/engagements").json() == []
    # Not 403: another client's record answers exactly like one that does not exist.
    assert other.get(f"/api/engagements/{ENGAGEMENT}").status_code == 404
    assert other.get(f"/api/timesheets/{TIMESHEET}/value").status_code == 404
    assert other.post(f"/api/timesheets/{TIMESHEET}/approve").status_code == 404
    assert "Azure landing zone" not in other.get("/").text
    assert other.get(f"/timesheets/{TIMESHEET}").status_code == 303
    assert as_user(ORPHAN).get("/api/timesheets").json() == []


def test_a_technical_contact_never_sees_day_rates(as_user):
    tech = as_user(DEMO_TECH)
    assert tech.get("/").headers["location"] == "/onboarding"
    assert tech.get("/api/engagements").status_code == 403
    assert tech.get("/api/timesheets").status_code == 403


def test_who_may_change_a_timesheet(as_user):
    # Submitted in the seed. The contractor cannot approve it; the client's approver can.
    assert as_user(CONTRACTOR).post(f"/api/timesheets/{TIMESHEET}/approve").status_code == 403
    page = as_user(CONTRACTOR).get(f"/timesheets/{TIMESHEET}").text
    assert "Approve" not in page and "waiting for the client" in page
    blocked = as_user(CONTRACTOR).post(f"/timesheets/{TIMESHEET}/approve")
    assert "may%20not%20approve" in blocked.headers["location"]

    approver = as_user(FIRST_APPROVER)
    assert "Approve" in approver.get(f"/timesheets/{TIMESHEET}").text
    assert approver.post(f"/api/timesheets/{TIMESHEET}/approve").json()["status"] == "approved"
    # Creating timesheets is HarvTech's side.
    body = {"engagement_id": ENGAGEMENT, "period": "2026-07", "entries": []}
    assert approver.post("/api/timesheets", json=body).status_code == 403
    assert as_user(ADMIN).post("/api/timesheets", json=body).status_code == 201
