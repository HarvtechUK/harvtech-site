---
title: "Azure API Management flaw: the hole is closed, but your secrets may already be out"
description: "Norway's security authority has tied attacks on two energy firms to a flaw in Azure API Management. Microsoft has closed it. The work left for customers is rotating secrets and checking for misuse."
published: 2026-11-25
tags: ["API Management", "Secrets", "Incident"]
sources:
  - label: "NSM (Norwegian National Security Authority): measures against the vulnerability in Azure API Management, 20 November 2026, updated 23 November (in Norwegian)"
    url: "https://nsm.no/aktuelt/nsm-deler-tiltak-mot-sarbarhet-i-azure-api-management"
  - label: "The Register: Norway links energy firm cyberattacks to critical Azure API Management flaw, 23 November 2026"
    url: "https://www.theregister.com/security/2026/11/23/norway-links-energy-firm-cyberattacks-to-critical-azure-api-management-flaw/5311598"
  - label: "Anders Kristiansen: hardening and log hunting guide for API Management, 21 November 2026"
    url: "https://anderskristiansen.com/post/2026/apim-legacy-access/"
  - label: "Skagerak Energi press release, 18 November 2026 (in Norwegian)"
    url: "https://www.skagerakenergi.no/presse/pressemeldinger/skagerak-energi-utsatt-for-forsok-pa-cyberangrep"
---

## What happened

On 20 November, Norway's National Security Authority (NSM) warned that an
unknown attacker had been actively using a vulnerability in Azure API
Management to go after access tokens, secrets and named values. NSM named
the energy companies Equinor and Skagerak Energi among the organisations
affected, and said the problem reaches beyond Norway and beyond the energy
sector.

Skagerak Energi described what it saw as a possible attempted attack, with
no effect on operations and no sign that information was taken. NSM says it
has no indication that deliveries at any Norwegian organisation were
affected.

NSM says the vulnerability is now closed. The Register, which has seen a
Microsoft advisory that is not public, reports that Microsoft identified the
issue on 18 November and applied a fix on its side the next day.

## Who is affected

According to The Register's account of Microsoft's advisory:

- Only the **classic tiers** of API Management are affected. The v2 tiers
  are not.
- Exposure is linked to instances that did not follow Microsoft's network
  security guidance, or that held secrets directly in API Management instead
  of referencing them from Azure Key Vault.

There is no public CVE number and no public Microsoft advisory at the time
of writing, so treat the detail above as reported, not confirmed. NSM says
plainly that nobody yet knows how widely the flaw was used.

## Why a closed hole is not the end of it

Microsoft's fix stops the access. It does not undo anything taken before the
fix went in. An API Management instance usually holds the keys to whatever
sits behind it: backend credentials, client secrets for sign-in providers,
subscription keys, and tokens for its own management API. If those were
read, they still work today, from anywhere, until someone changes them.

That is why NSM's advice is blunt: **assume the secrets and named values in
API Management have been compromised, and rotate all of them.**

## What to do

1. **List every API Management instance you have**, across every
   subscription. Forgotten development and test instances are the ones most
   likely to have been left on a default configuration.
2. **Check the runtime version.** NSM gives a check: open
   `https://<your-gateway-hostname>/internal-status-0123456789abcdef` and
   read `RuntimeVersion`. NSM's notice lists a version 0.52.x as fixed when
   its last number is 31936 or higher, and 0.53.x when it is 31938 or
   higher. Use the notice itself for the current figures. If an instance is
   below them, raise it with Microsoft or your provider.
3. **Rotate.** Named values, backend credentials, app registration secrets,
   subscription keys, the Key Vault secrets that API Management references,
   and the instance's own access keys.
4. **Work out what each instance can reach.** That tells you how far a
   stolen credential could have gone, and where to look first.
5. **Look for misuse.** Check the Azure Activity log, API Management gateway
   logs, Key Vault audit logs and service principal sign-ins for reads you
   cannot explain. Anders Kristiansen has published a set of queries and
   known attacker addresses to start from. Check first that those logs are
   switched on and how far back they go, because a log that was never
   collected cannot be searched afterwards.
6. **Close what you do not use.** Kristiansen's guide recommends turning
   off the direct management REST API, which signs in with a shared key
   instead of Entra ID, and unpublishing the developer portal if nobody uses
   it, or switching off self-service sign-up if they do. Neither has been
   confirmed as the route the attacker used.

One caution on Key Vault. Moving secrets out of named values and into Key
Vault is the right design and reduces what API Management holds. It is not a
reason to skip rotation here. As Kristiansen points out, someone able to
edit policies or switch on tracing in an instance can still read the values
it fetches from Key Vault.

## The wider point

As reported, what separated an exposed instance from a safe one was not
anything exotic. It was ordinary configuration: whether the network guidance
had been followed, and whether secrets were typed straight into the service.
Settings like those are found by looking, across the whole estate, before an
incident makes someone look.

The Azure Health Check could not have detected this flaw, and no scan of
configuration could. What it does report is the kind of setting that decides
how much an event like this costs you: API Management instances reachable
from the internet with no web application firewall in front, legacy TLS
still enabled, and developer portals open to anyone who signs up.
