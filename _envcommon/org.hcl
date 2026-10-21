# Common configuration for org units (<env>/<tenant>/org/).
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  org_vars = read_terragrunt_config(find_in_parent_folders("org.hcl"))

  catalog_url = "git::git@github.com:manujakau/vcloud-tf-modeler.git"
}

terraform {
  source = "${local.catalog_url}//modules/org?ref=${local.env_vars.locals.module_version}"
}

inputs = {
  name = local.org_vars.locals.org_name
}
