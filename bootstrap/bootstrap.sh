#!/usr/bin/env bash
#
# Platform-layer bootstrap for the harvtech-site repo.
# See ./README.md for context on why this exists.
#
# Idempotent for resource creates (re-running is a no-op if resources exist),
# but role assignment creates may report "already exists" errors which are
# safe to ignore.

set -euo pipefail

# --- Edit these if rebuilding under a different name / sub ---
LOCATION="uksouth"
PLATFORM_RG="rg-platform-prd-uks-01"
TFSTATE_SA="stplatformtfstateuks01"
TFSTATE_CONTAINER="tfstate"

APP_NAME="sp-github-harvtech-site"
GITHUB_ORG="HarvtechUK"
GITHUB_REPO="harvtech-site"
# --- End of edits ---

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant:       $TENANT_ID"
echo

# 1. Platform resource group
echo "==> Resource group: $PLATFORM_RG"
az group create \
  --name "$PLATFORM_RG" \
  --location "$LOCATION" \
  --tags purpose=platform managed_by=manual cost_centre=personal \
  --output none

# 2. State storage account (LRS is fine for personal use; client work
# would pick ZRS / GRS based on RTO/RPO requirements)
echo "==> Storage account: $TFSTATE_SA"
az storage account create \
  --name "$TFSTATE_SA" \
  --resource-group "$PLATFORM_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags purpose=platform-tfstate managed_by=manual \
  --output none

# 3. State container
echo "==> Container: $TFSTATE_CONTAINER"
az storage container create \
  --name "$TFSTATE_CONTAINER" \
  --account-name "$TFSTATE_SA" \
  --auth-mode login \
  --output none

# 4. Entra app + service principal
echo "==> Entra app: $APP_NAME"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)
if [ -z "${APP_ID:-}" ]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  az ad sp create --id "$APP_ID" --output none
fi
echo "    Client (app) ID: $APP_ID"

# 5. Federated credentials for GitHub OIDC
#    Two creds: one for pushes to main, one for PRs.
echo "==> Federated credentials"
for FC in "github-main:refs/heads/main:GitHub Actions on main branch" \
          "github-pr:pull_request:GitHub Actions on pull requests"; do
  NAME="${FC%%:*}"; REST="${FC#*:}"
  SUBJECT_TAIL="${REST%%:*}"; DESC="${REST#*:}"

  if [ "$SUBJECT_TAIL" = "pull_request" ]; then
    SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request"
  else
    SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:${SUBJECT_TAIL}"
  fi

  TMP=$(mktemp)
  cat > "$TMP" <<EOF
{
  "name": "$NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "$SUBJECT",
  "description": "$DESC",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
  az ad app federated-credential create --id "$APP_ID" --parameters "$TMP" --output none 2>/dev/null \
    || echo "    (federated cred '$NAME' already exists, skipping)"
  rm -f "$TMP"
done

# 6. RBAC
#    Contributor at subscription scope is broad. In a client engagement
#    you'd scope to a specific RG or use a custom role. For a personal
#    portfolio sub this is acceptable.
echo "==> RBAC: Contributor at subscription scope"
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --output none 2>/dev/null \
  || echo "    (already exists)"

echo "==> RBAC: Storage Blob Data Contributor on the state SA"
SA_ID=$(az storage account show --name "$TFSTATE_SA" --resource-group "$PLATFORM_RG" --query id -o tsv)
az role assignment create \
  --assignee "$APP_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$SA_ID" \
  --output none 2>/dev/null \
  || echo "    (already exists)"

# 7. Print values to copy into the GitHub repo settings
echo
echo "========================================================"
echo "Set these as repo secrets at"
echo "  https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/secrets/actions"
echo "--------------------------------------------------------"
echo "AZURE_CLIENT_ID:        $APP_ID"
echo "AZURE_TENANT_ID:        $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID:  $SUBSCRIPTION_ID"
echo "========================================================"
