# Common configuration for vdc units (<env>/<tenant>/<vdc>/vdc/).
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  org_vars = read_terragrunt_config(find_in_parent_folders("org.hcl"))

  catalog_url = "git::git@github.com:manujakau/vcloud-tf-modeler.git"
}

terraform {
  source = "${local.catalog_url}//modules/vdc?ref=${local.env_vars.locals.module_version}"
}

# Ordering only. org_name comes from org.hcl, so no output is wired, but
# run --all must still create the org before the VDC (and destroy it after).
dependencies {
  paths = ["${get_terragrunt_dir()}/../../org"]
}

inputs = {
  org = local.org_vars.locals.org_name
}
