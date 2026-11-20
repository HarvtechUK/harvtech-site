"""
In-memory sample data — a stand-in for the database while we learn.

Right now the app reads from these plain Python lists, so it runs
instantly on your machine with no Azure, no Cosmos DB and no login. In a
later step we'll replace this one module with a real Cosmos DB data
layer. The rest of the app should barely change, because the API
endpoints will still hand back the same Pydantic models defined in
models.py — that's the payoff of keeping data access in one place.

The single engagement below is your first real client: 40 days at £650.
"""

from datetime import UTC, date, datetime, timedelta

from .models import (
    Engagement,
    ItemState,
    ItemStatus,
    Onboarding,
    OnboardingEvent,
    RequestStatus,
    ServiceRequest,
    Timesheet,
    TimesheetEntry,
    TimesheetStatus,
)

ENGAGEMENTS: list[Engagement] = [
    Engagement(
        id="eng-2026-001",
        client_id="client-first",
        title="Azure landing zone — phase 1",
        day_rate=650,
        total_days=40,
        po_number="PO-0001",
        start_date=date(2026, 6, 1),
        contractor_id="alex",
    )
]

TIMESHEETS: list[Timesheet] = [
    Timesheet(
        id="ts-2026-06-client-first",
        client_id="client-first",
        engagement_id="eng-2026-001",
        contractor_id="alex",
        period="2026-06",
        status=TimesheetStatus.SUBMITTED,
        entries=[
            TimesheetEntry(work_date=date(2026, 6, 3), days=1, notes="Landing zone design"),
            TimesheetEntry(work_date=date(2026, 6, 4), days=0.5, notes="Stakeholder workshop"),
            TimesheetEntry(work_date=date(2026, 6, 5), days=1, notes="Terraform module build"),
        ],
    )
]


# ── Onboarding sample ────────────────────────────────────────────────────────
# A made-up health-check client part-way through onboarding, so the
# readiness dashboard has something to show the moment the app starts.
# These are functions (not constants) so each call builds fresh objects
# with timestamps relative to "now" — the page always looks recent.

DEMO_CLIENT_ID = "client-demo"


def onboardings() -> list[Onboarding]:
    now = datetime.now(UTC)

    def ago(days: float) -> datetime:
        return now - timedelta(days=days)

    def verified(detail: str, days: float) -> ItemState:
        return ItemState(
            status=ItemStatus.VERIFIED,
            done_by="priya.shah@example-insurance.co.uk",
            done_at=ago(days + 1),
            checked_by="HarvTech preflight",
            checked_at=ago(days),
            detail=detail,
        )

    def done(days: float) -> ItemState:
        return ItemState(
            status=ItemStatus.DONE, done_by="priya.shah@example-insurance.co.uk", done_at=ago(days)
        )

    return [
        Onboarding(
            id=DEMO_CLIENT_ID,
            client_id=DEMO_CLIENT_ID,
            client_name="Example Insurance",
            tiers=["A", "B", "C", "D", "E", "X"],
            created_at=ago(9),
            statement_acknowledged_by="priya.shah@example-insurance.co.uk",
            statement_acknowledged_at=ago(8),
            statement_version="1",
            items={
                "A1": verified("1,204 resources in 6 subscriptions are readable", 5),
                "A2": verified("12 metric definitions read on vm-web-prd-01", 5),
                "B1": ItemState(
                    status=ItemStatus.NEEDS_ATTENTION,
                    done_by="priya.shah@example-insurance.co.uk",
                    done_at=ago(4),
                    checked_by="HarvTech preflight",
                    checked_at=ago(3),
                    detail="2 of 3 workspaces answered; refused: law-sentinel",
                ),
                "C1": verified("Readable: users, groups, service principals, licences", 3),
                "C2": done(1),
                "C3": done(1),
                "C4": done(1),
                "D1": done(0.5),
                "X1": verified("Production is the env=prod tag; UAT and dev by subscription", 6),
            },
            history=[
                OnboardingEvent(at=ago(9), who="HarvTech", what="Onboarding opened"),
                OnboardingEvent(
                    at=ago(8),
                    who="priya.shah@example-insurance.co.uk",
                    what="Accepted the security and data-handling statement (version 1)",
                ),
                OnboardingEvent(at=ago(5), who="HarvTech preflight", what="Verified A1, A2"),
                OnboardingEvent(
                    at=ago(3), who="HarvTech preflight", what="B1 needs attention: law-sentinel refused"
                ),
                OnboardingEvent(
                    at=ago(1), who="priya.shah@example-insurance.co.uk", what="Marked C2, C3, C4 as done"
                ),
            ],
        )
    ]


def requests() -> list[ServiceRequest]:
    now = datetime.now(UTC)
    return [
        ServiceRequest(
            id="req-demo-0001",
            client_id=DEMO_CLIENT_ID,
            kind="access_report",
            detail="For our supplier review: who at HarvTech can see our findings?",
            status=RequestStatus.DONE,
            raised_by="priya.shah@example-insurance.co.uk",
            raised_at=now - timedelta(days=7),
            response="One named consultant, signed in with multifactor authentication. Report attached to our email of the same date.",
            handled_by="HarvTech",
            closed_at=now - timedelta(days=6),
        )
    ]
