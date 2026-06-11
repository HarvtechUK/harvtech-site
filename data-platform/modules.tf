# Repo-wide naming and tagging conventions — see modules/ for the
# convention definitions shared by all stacks.

module "naming" {
  source      = "../modules/naming"
  project     = var.project
  workload    = "data"
  environment = var.environment
  location    = var.location
}

module "tags" {
  source      = "../modules/tags"
  project     = var.project
  workload    = "data"
  environment = var.environment
}
