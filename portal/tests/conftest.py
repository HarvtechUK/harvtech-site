"""
Shared test setup.

The tests run the real app against the in-memory store, and swap out one
thing: `require_user`, the dependency that says who is signed in. FastAPI
lets a test replace any dependency (`app.dependency_overrides`), so each
test can BE whoever it needs to be — an admin, one client's approver,
another client's technical contact — without a Microsoft sign-in.
"""

import pytest
from fastapi.testclient import TestClient

from app import store_memory
from app.auth import require_user
from app.main import app

ADMIN = {"oid": "a", "tid": "t", "email": "alex@harvtech.example", "role": "admin", "client_id": None}
CONTRACTOR = {"oid": "c", "tid": "t", "email": "dev@harvtech.example", "role": "contractor", "client_id": None}
# Two different clients, so a test can prove one cannot see the other.
DEMO_TECH = {"oid": "d1", "tid": "t1", "email": "priya@demo.example", "role": "client_technical", "client_id": "client-demo"}
DEMO_APPROVER = {"oid": "d2", "tid": "t1", "email": "cfo@demo.example", "role": "client_approver", "client_id": "client-demo"}
FIRST_APPROVER = {"oid": "f1", "tid": "t2", "email": "pm@first.example", "role": "client_approver", "client_id": "client-first"}
OTHER_TECH = {"oid": "o1", "tid": "t3", "email": "eng@other.example", "role": "client_technical", "client_id": "client-other"}
# A half-configured account: a client role with no client. Must see nothing.
ORPHAN = {"oid": "x", "tid": "t9", "email": "who@nowhere.example", "role": "client_approver", "client_id": None}


@pytest.fixture(autouse=True)
def fresh_store():
    """Every test starts from the seed data."""
    store_memory.reset()
    yield
    app.dependency_overrides.clear()


class Browser:
    """A test browser signed in as one user.

    The override is set again before every request, because it is global to
    the app: a test that talks as the client, then as the admin, then as the
    client again must be the right person each time.
    """

    def __init__(self, user: dict | None):
        self.user = user
        self._client = TestClient(app, follow_redirects=False)

    def _as_me(self) -> None:
        app.dependency_overrides[require_user] = lambda: self.user

    def get(self, url: str, **kwargs):
        self._as_me()
        return self._client.get(url, **kwargs)

    def post(self, url: str, **kwargs):
        self._as_me()
        return self._client.post(url, **kwargs)


@pytest.fixture
def as_user():
    """`client = as_user(DEMO_TECH)` gives a browser signed in as that user."""
    return Browser
