# bootstrap/

Manual platform-layer setup that pre-exists every Terraform-managed stack in
this repo.

## Why manual

Terraform needs a remote backend to store state. That backend itself has to
exist before Terraform can do anything — classic chicken-and-egg. Likewise,
the Entra service principal that Terraform federates to needs to exist before
any Terraform-managed RBAC can assign roles to it.

So the platform layer (resource group, storage account, Entra app, federated
credentials, baseline RBAC) is created out of band, once, and then **never
re-run automatically**. Application stacks (`infra/`, `dns/`) consume what
this layer provides.

This is the standard pattern in real-world Azure landing zones: a small,
high-privilege "platform" tenant managed by SREs is separate from the
broader application estate where developers can move faster.

## What this layer provides

| Resource | Name | Purpose |
| --- | --- | --- |
| Resource group | `rg-platform-prd-uks-01` | Container for everything below |
| Storage account | `stplatformtfstateuks01` | Holds Terraform state for all stacks (`site.tfstate`, `dns.tfstate`, future stacks) |
| Blob container | `tfstate` | One container, one state blob per stack |
| Entra app | `sp-github-harvtech-site` | Identity GitHub Actions federates to |
| Federated credentials | `github-main`, `github-pr` | Trust for `refs/heads/main` and `pull_request` from this repo |
| RBAC (sub scope) | Contributor on subscription | Lets the SP manage application resources |
| RBAC (SA scope) | Storage Blob Data Contributor on the state SA | Lets the SP read/write state blobs |

## Running this

Only re-run if you're rebuilding from scratch in a fresh subscription or
recovering from disaster. Idempotency is best-effort, not guaranteed —
designed to be read more than executed.

```bash
./bootstrap.sh
```

The script is structured so you can run it as a whole, or paste it block by
block (which is how it was originally executed). Each block prints the
values you'll need for GitHub repo settings at the end.

## GitHub repo settings (set after running the script)

After running the script, set the three Entra IDs as **secrets** (not vars)
on the repo at github.com/HarvtechUK/harvtech-site/settings/secrets/actions:

- `AZURE_CLIENT_ID` — the app registration's client ID
- `AZURE_TENANT_ID` — the Entra tenant ID
- `AZURE_SUBSCRIPTION_ID` — the subscription ID

These aren't strictly secret (they're visible in the Azure portal to anyone
with read access), but Secrets-not-Variables keeps them out of CI logs by
default.

No state backend variables are needed — backend config is hardcoded in each
stack's `backend.tf`.

## What lives here vs in Terraform

| In Terraform | Here (manual) |
| --- | --- |
| Site infra (RG, storage, Front Door, WAF, DNS records) | Platform RG + state SA |
| Entra app's RBAC on the site RG (planned) | Entra app registration + federated credentials |
| DNS records in `harvtech.co.uk` | The DNS zone itself + the RG holding it |

The split deliberately mirrors the access boundary: developers / agents
that touch application code can't accidentally modify platform resources
that affect every project.
