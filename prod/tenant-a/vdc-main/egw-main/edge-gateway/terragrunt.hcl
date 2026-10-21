include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/edge_gateway.hcl"
}

# org and owner_id (= vdc_id from ../../vdc) are wired in _envcommon/edge_gateway.hcl.
inputs = {
  name                  = "TODO" # was edge_gateway_name
  description           = "TODO" # was edge_gateway_description
  external_network_name = "TODO" # was edge_gateway_external_network_name

  # was edge_gateway_subnets: one object per subnet. primary_ip must be inside allocated_ips.
  # The NAT unit (../nat) must use addresses from allocated_ips as external_address.
  subnets = [
    {
      gateway       = "TODO"
      prefix_length = "TODO"
      primary_ip    = "TODO"
      allocated_ips = [
        { start_address = "TODO", end_address = "TODO" },
      ]
    },
  ]

  # Not set in terraform.tfvars; the old root and module defaults agree:
  # dedicate_external_network = false, edge_cluster_id = null.
}
