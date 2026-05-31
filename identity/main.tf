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
