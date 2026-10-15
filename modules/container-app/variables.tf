variable "name" {
  description = "Container app name. Must follow the CAF convention (ca-…), which modules/naming produces."
  type        = string

  validation {
    condition     = can(regex("^ca-[a-z0-9-]{0,28}[a-z0-9]$", var.name)) && !strcontains(var.name, "--")
    error_message = "name must start with \"ca-\", be at most 32 lowercase letters, digits and single hyphens, and end with a letter or digit. Use module.naming.container_app."
  }
}

variable "resource_group_name" {
  description = "Resource group to deploy into, normally module.resource_group.name."
  type        = string
}

variable "container_app_environment_id" {
  description = "Environment to run in, normally module.container_app_environment.id. The app inherits the environment's region and network."
  type        = string
}

variable "tags" {
  description = "Tags for the app, normally module.tags.tags. Must contain every key in required_tag_keys."
  type        = map(string)

  validation {
    condition     = alltrue([for key in var.required_tag_keys : contains(keys(var.tags), key)])
    error_message = "tags is missing one or more required keys (see required_tag_keys). Pass module.tags.tags rather than a hand-built map."
  }
}

variable "required_tag_keys" {
  description = "Tag keys the app must carry. Defaults to the ownership and cost keys modules/tags emits."
  type        = list(string)
  default     = ["project", "workload", "environment", "owner", "cost_centre", "managed_by"]
}

# --- Container ----------------------------------------------------------

variable "image" {
  description = "Image for the FIRST deployment only. After that the deployment pipeline owns the running image (it is in ignore_changes), so changing this does nothing to an existing app."
  type        = string
}

variable "container_name" {
  description = "Name of the container within the app."
  type        = string
  default     = "app"
}

variable "cpu" {
  description = "vCPU per replica (Consumption plan: 0.25 to 4, in steps of 0.25)."
  type        = number
  default     = 0.25

  validation {
    condition     = var.cpu >= 0.25 && var.cpu <= 4 && floor(var.cpu * 4) == var.cpu * 4
    error_message = "cpu must be between 0.25 and 4 in steps of 0.25."
  }
}

variable "memory" {
  description = "Memory per replica. The Consumption plan requires twice the CPU in Gi (0.25 CPU = 0.5Gi)."
  type        = string
  default     = "0.5Gi"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?Gi$", var.memory))
    error_message = "memory must be a Gi quantity such as 0.5Gi or 1Gi."
  }
}

variable "min_replicas" {
  description = "Minimum replicas. 0 scales to zero when idle (nothing to pay at rest, but a cold start on the first request)."
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "Maximum replicas."
  type        = number
  default     = 1

  validation {
    condition     = var.max_replicas >= 1 && var.max_replicas <= 300
    error_message = "max_replicas must be between 1 and 300."
  }
}

variable "revision_mode" {
  description = "Single (a new revision replaces the old once healthy) or Multiple (revisions run side by side for blue/green)."
  type        = string
  default     = "Single"

  validation {
    condition     = contains(["Single", "Multiple"], var.revision_mode)
    error_message = "revision_mode must be Single or Multiple."
  }
}

variable "health_probe_path" {
  description = "HTTP path for liveness and readiness probes (for example /healthz). null keeps the platform's default TCP probe, which only proves the port is open, not that the app works."
  type        = string
  default     = null

  validation {
    condition     = var.health_probe_path == null || startswith(coalesce(var.health_probe_path, "/"), "/")
    error_message = "health_probe_path must start with \"/\"."
  }
}

# --- Ingress ------------------------------------------------------------

variable "target_port" {
  description = "Port the container listens on."
  type        = number

  validation {
    condition     = var.target_port >= 1 && var.target_port <= 65535
    error_message = "target_port must be a valid TCP port."
  }
}

variable "external_ingress_enabled" {
  description = "Expose the app outside its environment. Off by default: an app is reachable only by other apps in the same environment until it is made public deliberately."
  type        = bool
  default     = false
}

# --- Configuration and secrets ------------------------------------------

variable "env" {
  description = "Plain (non-secret) environment variables, by name. Values end up in Terraform state and the portal, so never put a secret here: use secrets and secret_env."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = <<-EOT
    Secrets the app can read, keyed by secret name. Each one is a Key
    Vault REFERENCE: there is deliberately no way to pass a value, so no
    secret can reach Terraform state through this module.
    key_vault_secret_id must be versionless
    (https://<vault>.vault.azure.net/secrets/<name>) so a rotated value is
    picked up without a code change. identity is the managed identity
    that reads the vault: "System" (default) or a user-assigned
    identity's resource ID.
  EOT
  type = map(object({
    key_vault_secret_id = string
    identity            = optional(string, "System")
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, secret in var.secrets :
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", name)) &&
      can(regex("^https://[a-zA-Z0-9-]+\\.vault\\.azure\\.net/secrets/[a-zA-Z0-9-]+/?$", secret.key_vault_secret_id))
    ])
    error_message = "Secret names must be lowercase letters, digits and hyphens, and key_vault_secret_id must be a VERSIONLESS Key Vault secret URL (https://<vault>.vault.azure.net/secrets/<name>)."
  }
}

variable "secret_env" {
  description = "Environment variables whose values come from secrets, as { ENV_VAR_NAME = \"secret-name\" }. The app sees the value; Terraform, the portal and the env listing only see the secret name."
  type        = map(string)
  default     = {}
}

variable "registry" {
  description = "Private registry to pull from with a managed identity (no username or password). identity is \"system\" (default) or a user-assigned identity's resource ID. null for public images."
  type = object({
    server = string
    # Lowercase on purpose: Azure stores the registry identity as
    # "system", so "System" here would show a diff on every plan. (Secret
    # identities are the opposite: the provider only accepts "System".)
    identity = optional(string, "system")
  })
  default = null
}

variable "user_assigned_identity_ids" {
  description = "User-assigned identities to attach alongside the system-assigned one. Useful for a first deployment, where a system identity cannot be granted AcrPull or Key Vault access before the app exists."
  type        = list(string)
  default     = []
}
