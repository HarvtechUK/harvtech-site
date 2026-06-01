# Conditional Access policies.
#
# All policies are created with `state = var.policy_state` which defaults
# to "enabledForReportingButNotEnforced" — Microsoft's safe-rollout mode:
# the engine evaluates the policy against every sign-in and records what
# WOULD have happened in the Entra sign-in logs, but doesn't actually
# enforce. Verify in logs, then flip the variable to "enabled" in a
# follow-up commit.
#
# Every policy excludes the break-glass user. ALWAYS. Even policies that
# look like they could never lock anyone out — a misconfiguration in the
# Conditions block of a "block legacy auth" policy can still produce
# unexpected behaviour. The exclusion list is the only safe default.
#
# Built-in client app types: "all" matches everything. Restricting to
# specific app types ("browser", "mobileAppsAndDesktopClients",
# "exchangeActiveSync", "other") is how you reach legacy / modern auth
# distinctions for the "block legacy auth" policy.

locals {
  break_glass_exclusions = [data.azuread_user.break_glass.object_id]
}

# 1. Require MFA for all users on all cloud apps.
#    Replaces Security Defaults' equivalent. The most foundational policy.
resource "azuread_conditional_access_policy" "require_mfa_all_users" {
  display_name = "CA001 - Require MFA for all users"
  state        = var.policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = local.break_glass_exclusions
    }

    locations {
      included_locations = ["All"]
    }

    platforms {
      included_platforms = ["all"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# 2. Block legacy authentication.
#    Replaces Security Defaults' equivalent. POP3 / IMAP / SMTP AUTH with
#    basic password (no MFA capability) gets rejected outright.
resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "CA002 - Block legacy authentication"
  state        = var.policy_state

  conditions {
    # Legacy auth surfaces only in these two client app types.
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = local.break_glass_exclusions
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# 3. Require PHISHING-RESISTANT MFA for admin sign-ins.
#    Stronger than policy 1 — admin roles can't use Authenticator TOTP
#    (phishable), only FIDO2 / passkey / Windows Hello.
#    Built-in "Phishing-resistant MFA" authentication strength. The
#    provider wants this as the full Graph URL path, not just the GUID
#    (a gotcha — error message is the cryptic "Segment 0 - not found").
resource "azuread_conditional_access_policy" "admin_phishing_resistant_mfa" {
  display_name = "CA003 - Admins must use phishing-resistant MFA"
  state        = var.policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = local.break_glass_exclusions
      # Privileged role holders, listed in terraform.tfvars so tightening
      # or relaxing the set is a tfvars edit, not a resource code change.
      included_roles = var.phishing_resistant_admin_roles
    }
  }

  grant_controls {
    operator                          = "OR"
    authentication_strength_policy_id = "/policies/authenticationStrengthPolicies/00000000-0000-0000-0000-000000000004"
  }
}

# 4. Block sign-ins from outside the allowed countries.
#    Uses the Named Location defined in main.tf. Sign-ins from countries
#    NOT in the allowlist get blocked outright. If Alex travels, add the
#    destination to var.allowed_country_codes BEFORE leaving.
#
#    depends_on the time_sleep so Terraform waits for Graph to propagate
#    the Named Location before creating the policy that references it
#    (see main.tf for the race condition this prevents).
resource "azuread_conditional_access_policy" "geo_block" {
  display_name = "CA004 - Block sign-ins from outside allowed countries"
  state        = var.policy_state

  depends_on = [time_sleep.wait_for_named_location]

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = local.break_glass_exclusions
    }

    locations {
      included_locations = ["All"]
      # `.object_id` returns just the UUID; `.id` returns the full Graph
      # URL path (/identity/conditionalAccess/namedLocations/<uuid>) which
      # CA policy expressions reject with a misleading
      # "NamedLocation ... does not exist" error.
      excluded_locations = [azuread_named_location.allowed_countries.object_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# 5. Sign-in frequency: re-authenticate every 12 hours for admin sessions.
#    Mitigates token theft — even if a session cookie is exfiltrated, it
#    can only be replayed for at most 12 hours before re-auth is forced.
#    Day-to-day this is barely noticeable (one extra passkey tap per
#    workday) but it bounds the blast radius of session-cookie compromise.
resource "azuread_conditional_access_policy" "admin_signin_frequency" {
  display_name = "CA005 - Admin sign-in frequency 12h"
  state        = var.policy_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = local.break_glass_exclusions
      # Tighter subset than CA003 — only the two roles with broadest
      # reach. Source of truth in terraform.tfvars.
      included_roles = var.frequent_reauth_admin_roles
    }
  }

  # Session controls (not grant controls) for sign-in frequency.
  session_controls {
    sign_in_frequency        = 12
    sign_in_frequency_period = "hours"
  }

  # Grant controls block is required by the API even when only session
  # controls are doing the work. "passwordChange" would be a typo on the
  # API; "mfa" is the no-op-when-already-mfa'd safe default.
  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
