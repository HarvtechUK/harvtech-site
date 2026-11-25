"""
The onboarding checklist — what a health-check client grants, tier by tier.

This is DATA, not logic: the tiers, the items in each, and the words the
client reads. The pages render from it and the rules in
onboarding_services.py count over it, so adding a checklist item is one
entry here and nothing else.

The item ids (A1, B1, C3 ...) are a CONTRACT with the scanning engine.
`finops preflight` in the harvtech-finops repository probes each grant
and writes its results keyed by these same ids; the admin page imports
that file to mark items verified. Change an id here and it must change
in `engine/src/finops/preflight.py` too.
"""

from dataclasses import dataclass, field


@dataclass(frozen=True)
class Tier:
    key: str
    name: str
    grant: str
    # What the client gets for granting it — the sentence on the tier card.
    unlocks: str
    # How many of the health check's rules this tier switches on. For most
    # tiers that is one number for the whole tier; where `per_item` is
    # True each item is an independent extra with its own count.
    rules: int = 0
    per_item: bool = False
    optional: bool = False


@dataclass(frozen=True)
class Item:
    id: str
    tier: str
    title: str
    # Who at the client can do this — it decides who they forward it to.
    who: str
    # Plain steps, in order.
    steps: tuple[str, ...]
    # A command to copy, where there is one. <placeholders> are theirs to fill.
    command: str = ""
    # How HarvTech checks it: "preflight" (an automatic read-only probe) or
    # "review" (we confirm it together).
    verified_by: str = "preflight"
    rules: int = 0
    notes: tuple[str, ...] = field(default_factory=tuple)


TIERS: tuple[Tier, ...] = (
    Tier(
        "A",
        "Reader",
        "Reader on the subscriptions in scope",
        "Every cost, security and network check that reads configuration and metrics: "
        "right-sizing, idle and orphaned resources, licensing, exposure, end of support.",
        rules=305,
    ),
    Tier(
        "B",
        "Logs",
        "Log Analytics Reader on your workspaces",
        "What is actually happening: denied and internet-facing traffic, firewall flows, "
        "virtual desktop usage, log ingestion you pay for and never query.",
        rules=13,
    ),
    Tier(
        "C",
        "Identity",
        "Read-only Microsoft Graph permissions",
        "Standing privileged roles, dormant and guest administrators, expiring app "
        "secrets, Conditional Access gaps, licences on accounts nobody uses.",
        rules=8,
    ),
    Tier(
        "D",
        "Commitments",
        "Reservations Reader and Savings plan reader",
        "Reservations and savings plans that are under-used or about to lapse, and "
        "steady workloads with nothing reserved.",
        rules=7,
    ),
    Tier(
        "E",
        "Extras",
        "Optional, each one independent",
        "Depth where you want it: Databricks workspaces, SQL Server files, profile "
        "shares, serverless SQL and Analysis Services.",
        per_item=True,
        optional=True,
    ),
    Tier(
        "X",
        "Context",
        "Two short conversations",
        "Findings that are right first time: we need to know what you call production, "
        "and which licences you already own.",
    ),
)

ITEMS: tuple[Item, ...] = (
    Item(
        "A1",
        "A",
        "Give the scan identity Reader on the subscriptions in scope",
        "Azure administrator (Owner or User Access Administrator)",
        (
            "Create the scan identity we agreed (a service principal in your tenant, or "
            "an Azure Lighthouse delegation).",
            "Assign the built-in Reader role at the management group above the "
            "subscriptions in scope, or on each subscription.",
        ),
        command=(
            'az role assignment create --assignee <app-id> --role Reader \\\n'
            "  --scope /providers/Microsoft.Management/managementGroups/<mg-id>"
        ),
        notes=("Reader cannot change anything, and cannot read data inside storage, databases or vaults.",),
    ),
    Item(
        "A2",
        "A",
        "Platform metrics are readable",
        "Nothing to do",
        ("Reader already includes this. We check it so a custom role or deny assignment does not surprise us later.",),
    ),
    Item(
        "B1",
        "B",
        "Give the scan identity Log Analytics Reader on your workspaces",
        "Azure administrator",
        (
            "For each workspace that holds flow logs, firewall logs, virtual desktop "
            "diagnostics or audit logs, assign Log Analytics Reader to the scan identity.",
            "We run a fixed set of queries, each only where its tables exist.",
        ),
        command=(
            'az role assignment create --assignee <app-id> --role "Log Analytics Reader" \\\n'
            "  --scope <workspace resource id>"
        ),
    ),
    Item(
        "C1",
        "C",
        "Consent Directory.Read.All",
        "Global Administrator or Privileged Role Administrator",
        (
            "On the scan app registration, add the Microsoft Graph application "
            "permission Directory.Read.All and grant admin consent.",
        ),
        notes=("Reads users, groups, service principals and licence counts. No mail, files or passwords.",),
    ),
    Item(
        "C2",
        "C",
        "Consent RoleManagement.Read.Directory",
        "Global Administrator or Privileged Role Administrator",
        ("Add the application permission RoleManagement.Read.Directory and grant admin consent.",),
        notes=("Reads directory roles and Privileged Identity Management schedules.",),
    ),
    Item(
        "C3",
        "C",
        "Consent Application.Read.All",
        "Global Administrator or Privileged Role Administrator",
        ("Add the application permission Application.Read.All and grant admin consent.",),
        notes=("Reads app registrations and when their secrets expire, never the secrets.",),
    ),
    Item(
        "C4",
        "C",
        "Consent Policy.Read.All",
        "Global Administrator or Privileged Role Administrator",
        ("Add the application permission Policy.Read.All and grant admin consent.",),
        notes=("Reads Conditional Access policies.",),
    ),
    Item(
        "C5",
        "C",
        "Consent AuditLog.Read.All",
        "Global Administrator or Privileged Role Administrator",
        (
            "Add the application permission AuditLog.Read.All and grant admin consent.",
            "Needs an Entra ID P1 licence in the tenant; without one, last sign-in dates are not available.",
        ),
        notes=("Last sign-in dates are how we tell a dormant administrator from an active one.",),
    ),
    Item(
        "D1",
        "D",
        "Give the scan identity Reservations Reader",
        "Billing administrator, or an administrator with elevated access",
        ("Assign Reservations Reader at tenant scope.",),
        command=(
            'az role assignment create --assignee <app-id> --role "Reservations Reader" \\\n'
            "  --scope /providers/Microsoft.Capacity"
        ),
    ),
    Item(
        "D2",
        "D",
        "Give the scan identity Savings plan reader",
        "Billing administrator, or an administrator with elevated access",
        ("Assign Savings plan reader at tenant scope.",),
        command=(
            'az role assignment create --assignee <app-id> --role "Savings plan reader" \\\n'
            "  --scope /providers/Microsoft.BillingBenefits"
        ),
    ),
    Item(
        "E1",
        "E",
        "Add the scan identity to your Databricks workspaces",
        "Databricks workspace administrator",
        (
            "Add the scan identity as a user of each workspace.",
            "Workspace admin is needed only for the access token list; a plain user sees clusters, jobs and warehouses.",
        ),
        rules=11,
    ),
    Item(
        "E2",
        "E",
        "Run the SQL Server collection script",
        "Database administrator",
        (
            "On each SQL Server VM, run Collect-SqlVm.ps1 with a login holding VIEW SERVER STATE and VIEW ANY DEFINITION.",
            "It writes one JSON file per server. Look inside before sending: paths, sizes, dates, database names and editions. No data, no credentials.",
            "Send the files to HarvTech.",
        ),
        verified_by="review",
        rules=7,
    ),
    Item(
        "E3",
        "E",
        "Run the profile share collection script",
        "Virtual desktop or storage administrator",
        ("Run Collect-FslogixShare.ps1 from any machine that can read the profile share, and send us the file.",),
        verified_by="review",
        rules=1,
    ),
    Item(
        "E4",
        "E",
        "Run the serverless SQL pool collection script",
        "Synapse administrator",
        ("Run Collect-SynapseServerless.ps1 with a login that can read the pool's management views, and send us the file.",),
        verified_by="review",
        rules=1,
    ),
    Item(
        "E5",
        "E",
        "Run the Analysis Services collection script",
        "Analysis Services administrator",
        ("Run Collect-AnalysisServices.ps1 with a reader on the server, and send us the file.",),
        verified_by="review",
        rules=1,
    ),
    Item(
        "X1",
        "X",
        "Tell us what you call production",
        "Platform lead, with HarvTech",
        ("Confirm which tags, names or subscriptions mean production, UAT and development, so severities are right.",),
        verified_by="review",
    ),
    Item(
        "X2",
        "X",
        "Tell us which licences you own",
        "Licensing or procurement, with HarvTech",
        ("Confirm the SQL Server and Windows Server licences you hold with Software Assurance, so the Hybrid Benefit findings are real.",),
        verified_by="review",
    ),
)

TIER_BY_KEY = {t.key: t for t in TIERS}
ITEM_BY_ID = {i.id: i for i in ITEMS}
# The tiers a new onboarding starts with unless HarvTech chooses otherwise.
DEFAULT_TIERS = ("A", "B", "C", "D", "X")
TOTAL_RULES = sum(t.rules for t in TIERS) + sum(i.rules for i in ITEMS)


def items_in(tier_key: str) -> list[Item]:
    return [i for i in ITEMS if i.tier == tier_key]
