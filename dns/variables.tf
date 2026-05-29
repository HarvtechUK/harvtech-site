variable "dns_resource_group_name" {
  description = "Existing resource group that hosts the shared DNS zones. Pre-created, managed out of band."
  type        = string
  default     = "rg-dns-prd-uks-01"
}

variable "tags" {
  description = "Tags applied to DNS resources managed by this stack"
  type        = map(string)
  default = {
    project     = "harvtech-site"
    managed_by  = "terraform"
    repo        = "HarvtechUK/harvtech-site"
    cost_centre = "personal"
  }
}