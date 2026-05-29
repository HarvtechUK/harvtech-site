# dns/

Terraform stack for the `harvtech.co.uk` public DNS zone.

## Scope

Only `harvtech.co.uk` is managed here. The resource group `rg-dns-prd-uks-01`
is shared with other personal projects (alultech.com, nuveotech.com) — those
zones are deliberately left out of state and out of scope.

The RG itself is referenced via a `data` source and managed out of band.

## State

- Backend: same Azure Storage backend as `infra/`
- State key: `dns.tfstate`

## Records currently managed

| Name           | Type  | Purpose                          |
| -------------- | ----- | -------------------------------- |
| `@`            | MX    | Microsoft 365 mail               |
| `@`            | TXT   | SPF for Exchange Online          |
| `autodiscover` | CNAME | Outlook autodiscover             |

The apex NS and SOA records are managed implicitly by `azurerm_dns_zone`.

The apex `A` record and `asuid` TXT record that previously pointed at a
WordPress placeholder were removed before this stack was authored — see git
history of the parent repo for context.

## Coming soon

- `_dnsauth.harvtech.co.uk` TXT for Azure Front Door custom-domain validation
- Apex / `www` record pointing the site at Front Door
