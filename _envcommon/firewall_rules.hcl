# Common configuration for firewall units (<env>/<tenant>/<vdc>/<egw>/firewall/).
#
# vcd_nsxt_firewall owns the WHOLE ordered rule list of an edge gateway, so
# there must be exactly one firewall unit per edge gateway. A second unit
# pointing at the same gateway would overwrite this one's rules on every apply.
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  org_vars = read_terragrunt_config(find_in_parent_folders("org.hcl"))

  catalog_url = "git::git@github.com:manujakau/vcloud-tf-modeler.git"
}

terraform {
  source = "${local.catalog_url}//modules/firewall_rules?ref=${local.env_vars.locals.module_version}"
}

dependency "vdc" {
  config_path = "${get_terragrunt_dir()}/../../vdc"

  mock_outputs = {
    vdc_id = "urn:vcloud:vdc:00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "edge_gateway" {
  config_path = "${get_terragrunt_dir()}/../edge-gateway"

  mock_outputs = {
    gateway_id = "urn:vcloud:gateway:00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  org             = local.org_vars.locals.org_name
  vdc_id          = dependency.vdc.outputs.vdc_id
  edge_gateway_id = dependency.edge_gateway.outputs.gateway_id
}
