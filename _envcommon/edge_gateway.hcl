# Common configuration for edge gateway units (<env>/<tenant>/<vdc>/<egw>/edge-gateway/).
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  org_vars = read_terragrunt_config(find_in_parent_folders("org.hcl"))

  catalog_url = "git::git@github.com:manujakau/vcloud-tf-modeler.git"
}

terraform {
  source = "${local.catalog_url}//modules/edge_gateway?ref=${local.env_vars.locals.module_version}"
}

dependency "vdc" {
  config_path = "${get_terragrunt_dir()}/../../vdc"

  mock_outputs = {
    vdc_id = "urn:vcloud:vdc:00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  org      = local.org_vars.locals.org_name
  owner_id = dependency.vdc.outputs.vdc_id
}
