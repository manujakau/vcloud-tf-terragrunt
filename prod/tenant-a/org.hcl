# Tenant-wide settings. Every unit below this folder reads org_name from here
# instead of from the org unit's outputs, so units that consume org_name do
# not need a dependency block on ../org. The vdc unit still declares an
# ordering dependency so that run --all creates the org first.
locals {
  org_name = "TODO" # was org_name in terraform.tfvars
}
