# Resource group for the data-platform stack: UK-region, tag and RBAC
# guardrails come from modules/resource-group.
module "resource_group" {
  source   = "../modules/resource-group"
  name     = local.rg_name
  location = var.location
  tags     = module.tags.tags
}

# --- ADLS Gen2 storage account ---
# hierarchical_namespace_enabled is what makes this a Data Lake Storage
# Gen2 account rather than plain blob storage: hierarchical namespace,
# POSIX-style ACLs, and the dfs.core.windows.net endpoint for
# Spark/Databricks-style filesystem access. The security baseline
# (Entra-only access, TLS 1.2, infrastructure encryption, soft delete,
# no local users) comes from modules/storage-account.
#
# Medallion layers are the containers: raw (bronze), cleansed (silver),
# curated (gold). Adding a layer = one entry in var.lakehouse_layers.
module "datalake" {
  source              = "../modules/storage-account"
  name                = local.datalake_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = module.tags.tags

  hierarchical_namespace_enabled = true
  containers                     = toset(var.lakehouse_layers)

  # LRS and public access: demo data, no private networking in this
  # stack (Checkov/Trivy suppressions and the productionisation path
  # are in /docs/architecture/data-platform-hld).
  replication_type              = "LRS"
  public_network_access_enabled = true
}
