# The ONE firewall unit for edge gateway egw-main.
#
# vcd_nsxt_firewall owns the whole ordered rule list of the edge gateway. Do not
# create a second firewall unit (or any other config) for this gateway: each
# apply would replace the other's rules. Add rules to firewall-rules.hcl instead.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/firewall_rules.hcl"
}

locals {
  firewall = read_terragrunt_config("${get_terragrunt_dir()}/firewall-rules.hcl")
}

# org, vdc_id and edge_gateway_id are wired in _envcommon/firewall_rules.hcl.
inputs = {
  rules = local.firewall.locals.rules
}
