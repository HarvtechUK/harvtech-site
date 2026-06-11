# Repo-wide naming and tagging conventions. Every resource name and
# tag map in this stack comes from these two calls — the conventions
# themselves live in modules/, shared by all stacks.

module "naming" {
  source      = "../modules/naming"
  project     = var.project
  workload    = "site"
  environment = var.environment
  location    = var.location
}

module "tags" {
  source      = "../modules/tags"
  project     = var.project
  workload    = "site"
  environment = var.environment
}
