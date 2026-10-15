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

# Entra app for "Sign in with Microsoft". Public identifier, safe in git.
portal_entra_client_id = "c4297773-7a12-4895-a9c3-422d2d7c34b3"
