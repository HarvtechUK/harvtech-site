variable "dns_resource_group_name" {
  description = "Existing resource group that hosts the shared DNS zones. Pre-created, managed out of band."
  type        = string
  default     = "rg-dns-prd-uks-01"
}

