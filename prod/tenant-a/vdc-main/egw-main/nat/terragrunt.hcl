include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/nat_rules.hcl"
}

# org, vdc_id and edge_gateway_id are wired in _envcommon/nat_rules.hcl.
#
# The addresses below are plain inputs for now and are NOT checked against
# other units:
#   - every external_address must be an IP from the edge gateway's
#     subnets[*].allocated_ips (../edge-gateway/terragrunt.hcl)
#   - every DNAT internal_address must be a host inside a network's CIDR, and
#     every SNAT internal_address a network CIDR (../networks/*/terragrunt.hcl)
# Update them together when the edge gateway allocation or network ranges change.
#
# Shape example:
#   dnat_rules = {
#     web-dnat = { external_address = "192.0.2.3", internal_address = "10.0.1.10", app_port_profile = "HTTP" }
#   }
#   snat_rules = {
#     outbound-snat = { internal_address = "10.0.1.0/24", external_address = "192.0.2.2" }
#   }
inputs = {
  # Replace with the dnat_rules / snat_rules maps from terraform.tfvars. Keep the
  # map keys unchanged: they are the resource keys in state.
  dnat_rules = {
    TODO = { external_address = "TODO", internal_address = "TODO" }
  }
  snat_rules = {
    TODO = { external_address = "TODO", internal_address = "TODO" }
  }
}
