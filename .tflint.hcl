config {
  format             = "default"
  call_module_type   = "local"
  disabled_by_default = false
  force              = false
}

# Azure-specific ruleset (SKU validation, deprecated args, naming).
plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Core Terraform rules.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Explicit opt-ins on top of the recommended preset.
rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}
