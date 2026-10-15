# Resource group for the site stack: UK-region, tag and RBAC guardrails
# come from modules/resource-group.
module "resource_group" {
  source   = "../modules/resource-group"
  name     = local.rg_name
  location = var.location
  tags     = module.tags.tags
}

# Static-site origin for Front Door. The security baseline (Entra-only
# access, TLS 1.2, infrastructure encryption, soft delete, no anonymous
# blob access) comes from modules/storage-account; only the trade-offs
# below are chosen here.
module "site_storage" {
  source              = "../modules/storage-account"
  name                = local.storage_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = module.tags.tags

  # LRS: everything in this account is rebuilt from git on each deploy,
  # so zone redundancy buys nothing (CKV_AZURE_206 / AZU-0058 suppressed
  # with the same reasoning).
  replication_type = "LRS"

  # Public on purpose. Front Door Standard cannot reach a storage origin
  # privately: Microsoft.Cdn/profiles is not a supported source for
  # storage resource instance rules
  # (https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-trusted-azure-services),
  # so denying by default would lock Front Door out too. The fixes are
  # Front Door Premium with Private Link to origin (~£200/mo uplift) or
  # a non-storage origin. Neither is justified for a static portfolio
  # site, so Trivy AZU-0012 is accepted and suppressed in .trivyignore.
  public_network_access_enabled = true

  static_website = {
    index_document     = "index.html"
    error_404_document = "404.html"
  }
}
