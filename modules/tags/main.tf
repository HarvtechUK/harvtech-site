# Standard tag set applied to every taggable resource in this repo.
#
# Tag changes are in-place updates in Azure — adopting or extending
# this module never forces a resource replacement.

terraform {
  required_version = ">= 1.9.0"
}

locals {
  standard = {
    project     = var.project
    workload    = var.workload
    environment = var.environment
    managed_by  = "terraform"
    repo        = var.repo
    cost_centre = var.cost_centre
    owner       = var.owner
  }
}
