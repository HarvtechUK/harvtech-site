# Central naming convention for every Azure resource in this repo.
#
# Pattern:  <caf-abbrev>-<project>-<workload>-<env>-<region>-<ordinal>
# Example:  rg-harvtech-site-prd-uks-01
#
# Resource types whose names forbid hyphens (storage accounts, Front
# Door WAF policies, key vaults at our length budget) use the same
# parts compacted:  stharvtechsiteprduks01
#
# CAF abbreviations follow the published Microsoft list:
# https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations

terraform {
  required_version = ">= 1.9.0"
}

locals {
  # Long region name -> short code used in names. Extending region
  # support = one entry here + one entry in the variable validation.
  region_short = {
    uksouth     = "uks"
    ukwest      = "ukw"
    northeurope = "neu"
    westeurope  = "weu"
  }[var.location]

  parts      = [var.project, var.workload, var.environment, local.region_short, var.ordinal]
  hyphenated = join("-", local.parts)
  compact    = join("", local.parts)
}

# Azure rejects over-long names at plan/apply with its own error, but
# these checks surface the problem at validate time with a message that
# says which input to shorten.
check "storage_account_name_length" {
  assert {
    condition     = length("st${local.compact}") <= 24
    error_message = "Storage account name 'st${local.compact}' exceeds 24 characters — shorten project or workload."
  }
}

check "key_vault_name_length" {
  assert {
    condition     = length("kv${local.compact}") <= 24
    error_message = "Key vault name 'kv${local.compact}' exceeds 24 characters — shorten project or workload."
  }
}
