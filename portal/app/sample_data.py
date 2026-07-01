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

from datetime import date

from .models import Engagement, Timesheet, TimesheetEntry, TimesheetStatus

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
