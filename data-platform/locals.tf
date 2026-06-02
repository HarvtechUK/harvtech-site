locals {
  # --- Core naming ---
  rg_name       = "rg-${var.project}-data-${var.environment}-uks"
  datalake_name = "st${var.project}data${var.environment}uks01"
  cosmos_name   = "cosmos-${var.project}-data-${var.environment}-uks"
  adf_name      = "adf-${var.project}-data-${var.environment}-uks"
  databricks_ws = "dbw-${var.project}-data-${var.environment}-uks"
  databricks_rg = "rg-databricks-managed-${var.project}-data-${var.environment}-uks"
}
