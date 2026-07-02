"""
Domain models for the timesheet portal.

These are *Pydantic* models. Pydantic is the data-validation library that
FastAPI is built on, and it's one of the most useful things to learn in
modern Python. Each class below describes the *shape* of a piece of
data — the field names, their types, and the rules each must satisfy.

From that description Pydantic does three jobs for you:

  1. Validation    — if incoming data doesn't fit (wrong type, missing
                     field, value out of range) it raises a clear error.
  2. Parsing       — it converts input into real Python types (an ISO
                     string "2026-06-03" becomes a datetime.date object).
  3. Serialization — it turns these objects back into JSON for the API.

Because FastAPI understands these models, it also builds the interactive
API documentation at /docs directly from them. Learn Pydantic well and a
lot of FastAPI falls into place for free.
"""

from datetime import date
from enum import Enum

from pydantic import BaseModel, Field, computed_field


class TimesheetStatus(str, Enum):
    """The lifecycle states a timesheet moves through.

    Inheriting from `str` as well as `Enum` means each member behaves
    like a plain string in JSON ("draft", "submitted", ...) while still
    giving us a fixed, typo-proof set of allowed values in code: you
    can write `TimesheetStatus.APPROVED` and the type checker/IDE will
    help you, and Pydantic will reject any value outside this set.
    """

    DRAFT = "draft"          # being filled in, not yet sent
    SUBMITTED = "submitted"  # sent to the client for sign-off
    APPROVED = "approved"    # client approved — this is what backs an invoice
    REJECTED = "rejected"    # client sent it back with questions


class TimesheetEntry(BaseModel):
    """A single day (or part-day) of delivered work."""

    # `Field(...)` with `...` (Ellipsis) means the field is REQUIRED.
    # The `ge`/`le` are validation rules: greater-than-or-equal /
    # less-than-or-equal. So `days` must be between 0 and 1 inclusive —
    # Pydantic rejects anything else before it reaches our code.
    work_date: date = Field(..., description="The day the work was done.")
    days: float = Field(
        ...,
        ge=0,
        le=1,
        description="Portion of the day delivered: 1.0 = full day, 0.5 = half day.",
    )
    notes: str = Field("", description="What was delivered that day.")


class Engagement(BaseModel):
    """A contracted piece of work for one client.

    The day rate and total days come from the signed agreement; the
    portal tracks delivery against them. We model consultancy *days*
    delivered (not hours), which keeps the language on the right side of
    the IR35 line — see docs/architecture/portal-hld.md.
    """

    id: str
    client_id: str
    title: str
    day_rate: float = Field(..., gt=0, description="Agreed day rate (gt=0 means must be positive).")
    currency: str = "GBP"
    total_days: float = Field(..., gt=0, description="Total days contracted.")
    po_number: str | None = None  # `| None` means optional — may be absent
    start_date: date
    contractor_id: str
    status: str = "active"


class Timesheet(BaseModel):
    """A period's worth of delivered days, submitted for client approval."""

    id: str
    client_id: str
    engagement_id: str
    contractor_id: str
    period: str = Field(..., description="The month this covers, e.g. '2026-06'.")
    # `default_factory=list` gives each new Timesheet its own empty list.
    # (Never use a plain `= []` default in Python — every instance would
    # secretly share the same list. This is a classic beginner trap.)
    entries: list[TimesheetEntry] = Field(default_factory=list)
    status: TimesheetStatus = TimesheetStatus.DRAFT

    @computed_field  # type: ignore[prop-decorator]
    @property
    def total_days(self) -> float:
        """Total days on this timesheet — the sum of every entry.

        A `computed_field` is *derived* from other fields rather than
        stored. It still appears in the JSON the API returns, but you
        never set it directly, so it can never drift out of sync with
        the entries it's calculated from. The money value (days × the
        engagement's day rate) is worked out in the API layer, because
        it needs the Engagement too — a model only sees its own fields.
        """
        return sum(entry.days for entry in self.entries)


class User(BaseModel):
    """A person allowed into the portal, and what they can do.

    Authentication proves *who* someone is (their Microsoft account);
    this record proves they're *allowed in*, and with what role. Anyone
    can authenticate with a work account — only people with a matching
    User record get access. The identity is bound to the stable Entra
    `oid` + `tid` (tenant), never email: emails can be reassigned or
    spoofed, oid+tid can't.
    """

    id: str  # equals the oid — one record per person; partition key
    oid: str = Field(..., description="Entra object ID — the stable user identifier.")
    tid: str = Field(..., description="Entra tenant ID — the user's home Microsoft 365 org.")
    email: str = ""
    name: str = ""
    role: str = Field(..., description="admin | contractor | client_approver")
    client_id: str | None = Field(
        None, description="For client_approver: which client they may approve for."
    )


class TimesheetCreate(BaseModel):
    """What a contractor *sends* to create a timesheet.

    This is a separate, smaller model from `Timesheet` on purpose, and
    it's an important habit: the request model contains only the fields
    a caller is allowed to set. Notice what's missing —

      - `id`            the server generates it
      - `status`        a new timesheet is always a draft; you can't
                        create one that's already "approved"
      - `client_id`     derived from the engagement, never trusted from
                        the request
      - `contractor_id` likewise derived

    If we accepted those from the request body, someone could forge a
    timesheet against another client, or mark their own work approved.
    Keeping the input model narrow is the first line of that defence —
    the server fills in the trusted fields itself in the endpoint.
    """

    engagement_id: str
    period: str = Field(..., description="The month covered, e.g. '2026-07'.")
    entries: list[TimesheetEntry] = Field(default_factory=list)
