# Auto-loaded by Terraform. Holds the role-template ID lists driving CA
# policy scoping — keeping them here means tightening or relaxing which
# roles get which policy is a tfvars edit, not a code change.
#
# Role-template IDs are well-known constants documented at
#   https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference
# (the "Template ID" column).

# Roles that should be required to use phishing-resistant MFA. This is
# every privileged role that can do meaningful tenant-wide damage if
# their MFA gets phished — basically the "admin" roles, broadly defined.
# Drives CA003.
phishing_resistant_admin_roles = [
  "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
  "194ae4cb-b126-40b2-bd5b-6091b380977d", # Security Administrator
  "f28a1f50-f6e7-4571-818b-6a12f2af6b6c", # SharePoint Administrator
  "29232cdf-9323-42fd-ade2-1d097af3e4de", # Exchange Administrator
  "729827e3-9c14-49f7-bb1b-9608f156bbb8", # Helpdesk Administrator
  "b0f54661-2d74-4c50-afa3-1ec803f12efe", # Billing Administrator
  "fe930be7-5e62-47db-91af-98c3a49a38b1", # User Administrator
  "c4e39bd9-1100-46d3-8c65-fb160da0071f", # Authentication Administrator
]

# Tighter list: roles whose session tokens are valuable enough to warrant
# a forced re-auth every 12 hours regardless of MFA strength. Just the
# two roles with the broadest "can change anything anywhere" reach.
# Drives CA005.
frequent_reauth_admin_roles = [
  "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
  "194ae4cb-b126-40b2-bd5b-6091b380977d", # Security Administrator
]
