# Look up the break-glass account to get its object ID. Using a data
# source rather than a hardcoded UUID means a rename / recreate is
# detectable as drift rather than a silent reference to a dead user.
data "azuread_user" "break_glass" {
  user_principal_name = var.break_glass_upn
}

# Named location: "allowed countries". Referenced by the geo-block
# CA policy. Add additional countries here if Alex travels.
resource "azuread_named_location" "allowed_countries" {
  display_name = "Allowed countries"

  country {
    countries_and_regions                 = var.allowed_country_codes
    include_unknown_countries_and_regions = false
  }
}

# Microsoft Graph has an eventual-consistency window between creating a
# Named Location and being able to reference it from a CA policy — on
# a fresh apply, Terraform hits a 400 "NamedLocation ... does not exist
# in the directory" if the policy create races the location's
# propagation. 60 seconds of sleep after the location is created is
# enough headroom on every empirical run we've seen.
#
# Only adds delay on the FIRST apply (when the location is being
# created); subsequent re-applies see the location and the sleep
# resource already in state and skip both.
resource "time_sleep" "wait_for_named_location" {
  depends_on      = [azuread_named_location.allowed_countries]
  create_duration = "60s"
}
