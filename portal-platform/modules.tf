# Repo-wide naming and tagging conventions — see modules/ for the
# definitions shared by all stacks.

module "naming" {
  source      = "../modules/naming"
  project     = var.project
  workload    = "portal"
  environment = var.environment
  location    = var.location
}

module "tags" {
  source      = "../modules/tags"
  project     = var.project
  workload    = "portal"
  environment = var.environment

  # Real client PII + financial records live here — tag it so it can
  # never be mistaken for the analytics-demo data platform.
  extra_tags = {
    data_classification = "confidential"
  }
}
