# LinkedIn company page kit

Copy and images for <https://www.linkedin.com/company/harvtechuk/>. Paste
these in by hand from **Edit page** on LinkedIn. Nothing here is applied
automatically.

## What is on the page today, and what to change

| Field | Today | Change to |
| --- | --- | --- |
| Cover image | none or default | `cover-1128x191@2x.png` |
| Logo | check it is the teal mark on black | `logo-400x400@2x.png` if not |
| Tagline | "Azure platform engineering, done right..." | see below |
| About | five service lines, ends "Get in touch: alex@" | see below, ends with enquiries@ |
| Button | check | **Visit website**, to `https://harvtech.co.uk/health-check` |
| Specialties | 20, no mention of the health check | see below |

## Tagline (120 characters allowed)

> Azure security, cost and compliance for London-market insurers. Findings shown with evidence, fixes delivered in code.

## About (2,000 characters allowed)

> HarvTech helps London-market insurers, MGAs, Lloyd's syndicates and brokers find and fix what is wrong in their Microsoft Azure estates: security exposure, wasted spend and network faults.
>
> The Azure Health Check
> A read-only review of your whole Azure estate. 354 checks across cost, security and network, covering 13 areas from SQL Server and storage to Entra ID and firewalls. Every finding comes with the evidence behind it, an estimated saving in pounds where there is one, and what it takes to fix: effort, downtime and how to roll back. Nothing in your estate is changed.
>
> Remediation in code
> When something needs fixing, we fix it in Terraform, with the evidence an auditor asks for: Entra ID and PIM, Conditional Access, Key Vault, Defender for Cloud, landing zones and networking.
>
> How we work
> Everything in code. Every decision written down. Documentation, runbooks and handover at the end of every engagement.
>
> HarvTech is led by Alex Harvey: 25 years in IT, the last seven on Azure at Lloyd's of London market insurers.
>
> We post short pieces on Azure security news here and at harvtech.co.uk/news: what happened, who is affected and what to check.
>
> Get in touch: enquiries@harvtech.co.uk

The figures 354 and 13 come from `site/src/data/healthCheck.ts`. Update this
text when they change.

## Specialties (20 allowed)

Microsoft Azure, Azure Health Check, Azure Security, Cloud Security,
Entra ID, Conditional Access, Privileged Identity Management,
Defender for Cloud, Key Vault, Azure Networking, FinOps,
Azure Cost Optimisation, SQL Server Licensing, Terraform,
Infrastructure as Code, Azure Landing Zones, Cloud Adoption Framework,
Lloyd's Market, Insurance, Regulated Industries

## Other things worth doing on the page

- **Pin a post** about the Azure Health Check linking to
  `https://harvtech.co.uk/health-check`.
- **Add the Health Check as a service** on the page's Services tab if it is
  offered to you.
- **Invite connections to follow.** LinkedIn gives each page a monthly
  allowance of invitations; 17 followers is the thing most worth fixing.
- **Share each company post from your own profile** with a line of your own.
  Personal posts reach far more people than page posts.

## Posting news

1. Write the article as a file in `site/src/content/news/` and release the
   site. The article gets its own address under `harvtech.co.uk/news/`.
2. Post on the company page with the article link. LinkedIn builds the
   preview card from the site's share image (`site/public/og-default.png`).
   If the card looks stale, paste the link into LinkedIn's Post Inspector to
   refresh it.
3. Share that post from your own profile.

A pattern that works: one line on what happened, two or three on who is
affected and what to do, then the link. Keep the detail on the site.

### Post for the first article

> Norway's security authority has tied attacks on two energy firms to a flaw in Azure API Management.
>
> Microsoft has closed the hole. That does not undo anything taken before the fix: if the secrets held in an instance were read, they still work until someone changes them.
>
> If you run API Management on a classic tier:
> ▸ Find every instance, including the test ones nobody remembers
> ▸ Check the runtime version against the published thresholds
> ▸ Rotate named values, backend credentials and subscription keys
> ▸ Check your logs for reads you cannot explain
>
> What we know, what is still unconfirmed, and the steps in order:
> https://harvtech.co.uk/news/azure-api-management-secrets-exposed
>
> #Azure #CloudSecurity #APIManagement #Insurance
