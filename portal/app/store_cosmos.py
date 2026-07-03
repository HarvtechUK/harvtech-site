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

from .models import Engagement, Timesheet, User

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
