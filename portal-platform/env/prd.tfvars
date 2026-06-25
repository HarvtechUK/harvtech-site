# Portal platform — production values. Passed via
# -var-file=env/prd.tfvars from the workflow, matching the other stacks.

# Cosmos containers for the portal database. engagements & timesheets
# partition by /clientId for per-tenant isolation; clients & users by
# /id. See docs/architecture/portal-hld.md for the document shapes.
portal_containers = {
  clients = {
    partition_key_path = "/id"
  }
  users = {
    partition_key_path = "/id"
  }
  engagements = {
    partition_key_path = "/clientId"
  }
  timesheets = {
    partition_key_path = "/clientId"
  }
}
