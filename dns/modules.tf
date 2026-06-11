# Repo-wide tagging convention — see modules/tags. This stack has no
# naming module call: the zone's name IS the domain, the record names
# are protocol-dictated (@, www, _dnsauth), and the resource group is
# a shared one referenced via data source.
#
# Inputs are literals rather than variables because this stack manages
# exactly one zone for one project in one environment — promoting them
# to variables would suggest a flexibility the stack doesn't have.

module "tags" {
  source      = "../modules/tags"
  project     = "harvtech"
  workload    = "dns"
  environment = "prd"
}
