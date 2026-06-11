locals {
  # --- Core naming (from the shared convention module) ---
  rg_name       = module.naming.resource_group
  datalake_name = module.naming.storage_account
  cosmos_name   = module.naming.cosmosdb_account
  adf_name      = module.naming.data_factory
  databricks_ws = module.naming.databricks_workspace
  databricks_rg = module.naming.databricks_managed_resource_group
}
