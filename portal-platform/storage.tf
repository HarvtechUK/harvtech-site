# Blob storage for published report PDFs.
#
# A client's health-check report is published to the portal as a small
# document (Cosmos, `reports`) and a PDF. The PDF goes here because a
# Cosmos document cannot exceed 2 MB. Blobs are named
# <client id>/report.pdf and are only ever read by the portal's own
# managed identity, which serves a PDF to a signed-in user of that client
# and nobody else; there are no SAS links and no public containers.

module "reports_storage" {
  source              = "../modules/storage-account"
  name                = module.naming.storage_account
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = module.tags.tags

  # A report can always be published again from its source, so paying for
  # zone redundancy would buy nothing.
  replication_type = "LRS"

  # Public on purpose, protected by Entra RBAC (the module disables shared
  # keys and anonymous access outright). Same reasoning as the Key Vault:
  # the Container Apps environment is not VNet-integrated, so a private
  # account would lock the portal out of its own reports.
  public_network_access_enabled = true

  containers = ["reports"]

  role_assignments = {
    # Read and write blobs, nothing else: the identity cannot change the
    # account, its network rules or its keys.
    portal_reports = {
      role_definition_id_or_name = "Storage Blob Data Contributor"
      principal_id               = module.container_app.principal_id
      principal_type             = "ServicePrincipal"
    }
  }
}
