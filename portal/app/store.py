"""
The data layer — the rest of the app imports `store` and calls these
functions, never caring where the data physically lives.

At startup this module picks ONE backend and re-exports its functions:

  - COSMOS_ENDPOINT set   → store_cosmos  (real Azure Cosmos DB)
  - COSMOS_ENDPOINT unset → store_memory  (in-memory, for local learning)

Both backends define the exact same function names with the same shapes,
so the choice is invisible to main.py. Selecting an implementation by
configuration like this — same interface, swappable behind it — is a
pattern you'll reach for constantly.
"""

import os

from . import store_cosmos, store_memory

# Pick the backend once, when the app starts.
_backend = store_cosmos if os.environ.get("COSMOS_ENDPOINT") else store_memory

# Re-export the chosen backend's functions under this module's namespace,
# so callers write `store.get_timesheet(...)` regardless of which one ran.
list_engagements = _backend.list_engagements
get_engagement = _backend.get_engagement
list_timesheets = _backend.list_timesheets
get_timesheet = _backend.get_timesheet
add_timesheet = _backend.add_timesheet
save_timesheet = _backend.save_timesheet
get_user = _backend.get_user

# Client onboarding and data-handling requests.
get_onboarding = _backend.get_onboarding
list_onboardings = _backend.list_onboardings
save_onboarding = _backend.save_onboarding
list_requests = _backend.list_requests
get_request = _backend.get_request
save_request = _backend.save_request

# Published reports (the document, and the PDF beside it) and activity.
get_report = _backend.get_report
save_report = _backend.save_report
get_report_pdf = _backend.get_report_pdf
save_report_pdf = _backend.save_report_pdf
add_activity = _backend.add_activity
list_activity = _backend.list_activity

# Handy for a log line / health output: which backend are we on?
BACKEND_NAME = _backend.__name__.rsplit(".", 1)[-1]
