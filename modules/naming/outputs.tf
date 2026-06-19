# One output per resource type. Adding support for a new type is one
# output block here — pick the abbreviation from the CAF list linked
# in main.tf, and use local.compact for types that forbid hyphens.

output "resource_group" {
  description = "Resource group name (rg-…)."
  value       = "rg-${local.hyphenated}"
}

output "storage_account" {
  description = "Storage account name (st… compact — Azure allows lowercase alphanumeric only, max 24 chars)."
  value       = "st${local.compact}"
}

output "cdn_frontdoor_profile" {
  description = "Front Door profile name (afd-…)."
  value       = "afd-${local.hyphenated}"
}

output "cdn_frontdoor_firewall_policy" {
  description = "Front Door WAF policy name (fdfp… compact — Azure allows letters and numbers only)."
  value       = "fdfp${local.compact}"
}

output "cosmosdb_account" {
  description = "Cosmos DB account name (cosno-… — CAF abbreviation for the NoSQL/Core API flavour)."
  value       = "cosno-${local.hyphenated}"
}

output "data_factory" {
  description = "Data Factory name (adf-…)."
  value       = "adf-${local.hyphenated}"
}

output "databricks_workspace" {
  description = "Databricks workspace name (dbw-…)."
  value       = "dbw-${local.hyphenated}"
}

output "databricks_managed_resource_group" {
  description = "Name to pin the Databricks-managed worker resource group to (otherwise Azure generates one with a GUID suffix)."
  value       = "rg-dbw-managed-${local.hyphenated}"
}

output "key_vault" {
  description = "Key vault name (kv… compact — the hyphenated form blows the 24-char limit at this repo's project/workload lengths)."
  value       = "kv${local.compact}"
}

output "static_web_app" {
  description = "Static Web App name (stapp-…)."
  value       = "stapp-${local.hyphenated}"
}

output "function_app" {
  description = "Function App name (func-…)."
  value       = "func-${local.hyphenated}"
}

output "app_service_plan" {
  description = "App Service / Function plan name (asp-…)."
  value       = "asp-${local.hyphenated}"
}

output "application_insights" {
  description = "Application Insights name (appi-…)."
  value       = "appi-${local.hyphenated}"
}

output "log_analytics_workspace" {
  description = "Log Analytics workspace name (log-…)."
  value       = "log-${local.hyphenated}"
}
