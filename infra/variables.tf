variable "location" {
  description = "Azure region"
  type        = string
  default     = "uksouth"
}

variable "project" {
  description = "Project name, used in resource naming"
  type        = string
  default     = "harvtech"
}

variable "environment" {
  description = "Environment short name"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    project     = "harvtech-site"
    managed_by  = "terraform"
    repo        = "HarvtechUK/harvtech-site"
    cost_centre = "personal"
  }
}
