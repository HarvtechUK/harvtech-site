variable "project" {
  description = "Project short name (e.g. harvtech). Kept separate from workload so cost reports can roll up either way."
  type        = string
}

variable "workload" {
  description = "Workload / stack short name (e.g. site, data, dns). Replaces the old pattern of baking the workload into the project tag."
  type        = string
}

variable "environment" {
  description = "Environment short code (dev / tst / stg / prd)."
  type        = string
}

variable "cost_centre" {
  description = "Cost centre the resource bills to."
  type        = string
  default     = "personal"
}

variable "owner" {
  description = "Contact for questions about the resource — first place an operator looks during an incident."
  type        = string
  default     = "alex@harvtech.co.uk"
}

variable "repo" {
  description = "GitHub repo that manages the resource. Closes the loop from portal to source."
  type        = string
  default     = "HarvtechUK/harvtech-site"
}

variable "extra_tags" {
  description = "Stack-specific tags merged over the standard set. Later keys win, so an entry here can also deliberately override a standard tag."
  type        = map(string)
  default     = {}
}
