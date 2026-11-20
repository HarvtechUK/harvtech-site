"""
Azure Cosmos DB implementation of the data layer.

Exposes the *same function names* as store_memory, so store.py can pick
either one at startup and the rest of the app never knows which is in
use. This is the module that actually talks to Azure.

Keyless auth: `DefaultAzureCredential` finds your `az login` identity
when you run locally, and the Container App's managed identity once
deployed. No keys, no connection strings — which is exactly why the
Cosmos account has local auth disabled in the portal-platform stack.
Run `az login` before starting the app with COSMOS_ENDPOINT set.

This file uses the *synchronous* Cosmos client — easiest to read. The
higher-performance choice for a busy service is azure.cosmos.aio (async),
which we can switch to later; the function signatures wouldn't change.
"""

import os
from functools import lru_cache

from azure.cosmos import ContainerProxy, CosmosClient, exceptions
from azure.identity import DefaultAzureCredential

from .models import (
    ActivityEvent,
    Engagement,
    Onboarding,
    Report,
    ServiceRequest,
    Timesheet,
    User,
)

_DATABASE_NAME = os.environ.get("COSMOS_DATABASE", "portal")


@lru_cache(maxsize=1)
def _client() -> CosmosClient:
    """Build the Cosmos client once and reuse it.

    `@lru_cache` memoises the result, so the first call constructs the
    client (and the credential) and every call after returns the same
    instance — you don't want to authenticate on every request. It's
    built lazily (on first use, not at import) so simply importing this
    module never needs a network or a login.
    """
    endpoint = os.environ["COSMOS_ENDPOINT"]  # guaranteed set when this backend is chosen
    return CosmosClient(url=endpoint, credential=DefaultAzureCredential())


def _container(name: str) -> ContainerProxy:
    """Handle to one container (table) in the portal database."""
    return _client().get_database_client(_DATABASE_NAME).get_container_client(name)


# --- Engagements ---

def list_engagements() -> list[Engagement]:
    # read_all_items() streams every document in the container; we turn
    # each dict back into a validated Engagement. Cosmos adds system
    # fields (_rid, _etag, ...) — Pydantic ignores unknown fields, so
    # they're harmlessly dropped.
    return [Engagement(**item) for item in _container("engagements").read_all_items()]


def get_engagement(engagement_id: str) -> Engagement | None:
    # Engagements are partitioned by /clientId, and here we only know the
    # id — so Cosmos must fan the query out across every partition, and
    # the SDK makes you say so EXPLICITLY (enable_cross_partition_query).
    # Without the flag the service refuses with "Cross partition query is
    # required but disabled" — which we learned the hard way; a previous
    # comment here wrongly claimed the SDK handles it automatically.
    # Parameterised (@id) rather than string-formatted — the same habit
    # as avoiding SQL injection in any database.
    rows = list(
        _container("engagements").query_items(
            query="SELECT * FROM c WHERE c.id = @id",
            parameters=[{"name": "@id", "value": engagement_id}],
            enable_cross_partition_query=True,
        )
    )
    return Engagement(**rows[0]) if rows else None


# --- Timesheets ---

def list_timesheets() -> list[Timesheet]:
    return [Timesheet(**item) for item in _container("timesheets").read_all_items()]


def get_timesheet(timesheet_id: str) -> Timesheet | None:
    # Same cross-partition situation as get_engagement above.
    rows = list(
        _container("timesheets").query_items(
            query="SELECT * FROM c WHERE c.id = @id",
            parameters=[{"name": "@id", "value": timesheet_id}],
            enable_cross_partition_query=True,
        )
    )
    return Timesheet(**rows[0]) if rows else None


def add_timesheet(timesheet: Timesheet) -> None:
    # create_item inserts a new document. model_dump(mode="json") turns
    # the Pydantic object into a JSON-safe dict (dates → ISO strings).
    # Cosmos reads the partition key (clientId) straight out of the body.
    _container("timesheets").create_item(body=timesheet.model_dump(mode="json"))


def save_timesheet(timesheet: Timesheet) -> None:
    # upsert_item writes the document, replacing any existing one with the
    # same id — the right call for a status change on a timesheet we
    # already created.
    _container("timesheets").upsert_item(body=timesheet.model_dump(mode="json"))


# --- Users (authorisation) ---

def get_user(oid: str, tid: str) -> User | None:
    """Find a registered portal user by Entra object id + tenant id.

    The users container is partitioned by /id, and a user's id IS their
    oid — which means we can do a *point read*: fetch by id + partition
    key directly, no query at all. Point reads are the cheapest, fastest
    operation Cosmos has (single-digit ms, ~1 RU); use them whenever you
    know both the id and the partition key.

    The tid check still matters: a user is only recognised from their own
    home tenant (defence in depth — oids shouldn't collide across
    tenants, but we verify rather than assume).
    """
    try:
        row = _container("users").read_item(item=oid, partition_key=oid)
    except exceptions.CosmosResourceNotFoundError:
        # No record with that id — an authenticated but unregistered
        # account. The caller treats None as "not allowed in".
        return None
    user = User(**row)
    return user if user.tid == tid else None


# --- Client onboarding ---
# The `onboarding` and `requests` containers are partitioned by /client_id
# (the field's real name in the document), so one client's records sit in
# one partition and a query for a client never leaves it.
#
# Every read here treats "not found" as "nothing yet". That covers a
# client with no onboarding, and also the short window in a release where
# the new app version is live before Terraform has created the container.

def get_onboarding(client_id: str) -> Onboarding | None:
    # id == client_id == partition key, so this is a point read.
    try:
        row = _container("onboarding").read_item(item=client_id, partition_key=client_id)
    except exceptions.CosmosResourceNotFoundError:
        return None
    return Onboarding(**row)


def list_onboardings() -> list[Onboarding]:
    try:
        return [Onboarding(**item) for item in _container("onboarding").read_all_items()]
    except exceptions.CosmosResourceNotFoundError:
        return []


def save_onboarding(onboarding: Onboarding) -> None:
    _container("onboarding").upsert_item(body=onboarding.model_dump(mode="json"))


# --- Data-handling requests ---

def list_requests(client_id: str | None = None) -> list[ServiceRequest]:
    try:
        if client_id is None:
            # Staff view: every client's requests, so every partition.
            rows = _container("requests").read_all_items()
        else:
            # A client's view: pinned to their partition. Cosmos cannot
            # return another client's request from this query even if the
            # WHERE clause were wrong, because it never opens their partition.
            rows = _container("requests").query_items(
                query="SELECT * FROM c WHERE c.client_id = @client_id",
                parameters=[{"name": "@client_id", "value": client_id}],
                partition_key=client_id,
            )
        return [ServiceRequest(**row) for row in rows]
    except exceptions.CosmosResourceNotFoundError:
        return []


def get_request(request_id: str) -> ServiceRequest | None:
    try:
        rows = list(
            _container("requests").query_items(
                query="SELECT * FROM c WHERE c.id = @id",
                parameters=[{"name": "@id", "value": request_id}],
                enable_cross_partition_query=True,
            )
        )
    except exceptions.CosmosResourceNotFoundError:
        return None
    return ServiceRequest(**rows[0]) if rows else None


def save_request(request: ServiceRequest) -> None:
    _container("requests").upsert_item(body=request.model_dump(mode="json"))


# --- Published reports ---
# The report document lives in Cosmos (`reports`, partitioned by
# /client_id, id = client id, so reading a client's report is a point
# read). The PDF lives in blob storage, because a Cosmos document cannot
# exceed 2 MB. Both are keyed by client id and nothing else: there is no
# way to ask for a report by any other handle.

def get_report(client_id: str) -> Report | None:
    try:
        row = _container("reports").read_item(item=client_id, partition_key=client_id)
    except exceptions.CosmosResourceNotFoundError:
        return None
    return Report(**row)


def save_report(report: Report) -> None:
    _container("reports").upsert_item(body=report.model_dump(mode="json"))


@lru_cache(maxsize=1)
def _blobs():
    """The blob container that holds report PDFs, keyless like Cosmos.

    Imported here, not at the top, so the app starts without the storage
    SDK doing anything until a PDF is actually read or written.
    """
    from azure.storage.blob import BlobServiceClient

    endpoint = os.environ["REPORTS_BLOB_ENDPOINT"]
    service = BlobServiceClient(account_url=endpoint, credential=DefaultAzureCredential())
    return service.get_container_client(os.environ.get("REPORTS_CONTAINER", "reports"))


def _pdf_name(client_id: str) -> str:
    return f"{client_id}/report.pdf"


def get_report_pdf(client_id: str) -> bytes | None:
    from azure.core.exceptions import ResourceNotFoundError

    try:
        return _blobs().download_blob(_pdf_name(client_id)).readall()
    except ResourceNotFoundError:
        return None


def save_report_pdf(client_id: str, content: bytes) -> None:
    _blobs().upload_blob(_pdf_name(client_id), content, overwrite=True)


# --- Activity ---

def add_activity(event: ActivityEvent) -> None:
    _container("activity").create_item(body=event.model_dump(mode="json"))


def list_activity(client_id: str | None = None, limit: int = 200) -> list[ActivityEvent]:
    """Newest first. A client's events come from their partition alone."""
    try:
        if client_id is None:
            rows = _container("activity").query_items(
                query="SELECT TOP @limit * FROM c ORDER BY c.at DESC",
                parameters=[{"name": "@limit", "value": limit}],
                enable_cross_partition_query=True,
            )
        else:
            rows = _container("activity").query_items(
                query="SELECT TOP @limit * FROM c WHERE c.client_id = @client_id ORDER BY c.at DESC",
                parameters=[
                    {"name": "@limit", "value": limit},
                    {"name": "@client_id", "value": client_id},
                ],
                partition_key=client_id,
            )
        return [ActivityEvent(**row) for row in rows]
    except exceptions.CosmosResourceNotFoundError:
        return []
