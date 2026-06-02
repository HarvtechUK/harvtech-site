# Data-platform stack — production values. Auto-loaded? No — passed
# via -var-file=env/prd.tfvars from the workflow, matching the
# convention used by infra/ and identity/.

# Medallion architecture containers. Adding a new layer = one entry.
lakehouse_layers = [
  "raw",      # bronze — source data, untransformed
  "cleansed", # silver — validated and typed
  "curated",  # gold — business-ready aggregates
]

# Cosmos databases and their containers. Two-level map so adding a
# database or container is a tfvars edit, not a resource block.
# Partition key paths must start with a leading slash.
cosmos_databases = {
  app = {
    containers = {
      sessions = {
        # /tenantId would be the typical real-world key — splits traffic
        # across partitions by which tenant the document belongs to.
        partition_key_path = "/tenantId"
      }
    }
  }
}

# Cosmos free-tier slot is unburnt on this subscription, so claim it.
enable_cosmos_free_tier = true

# Standard tier — enough for a portfolio demo. Premium adds Unity
# Catalog and finer RBAC, neither needed without real users.
databricks_sku = "standard"
