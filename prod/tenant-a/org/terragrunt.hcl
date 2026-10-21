include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/org.hcl"
}

# name comes from ../org.hcl via _envcommon/org.hcl.
inputs = {
  # Required by the provider. The module's "" default is not usable.
  full_name   = "TODO" # was org_full_name
  description = "TODO" # was org_description
  # is_enabled: not set in terraform.tfvars; the old root and module defaults agree (true).
}
