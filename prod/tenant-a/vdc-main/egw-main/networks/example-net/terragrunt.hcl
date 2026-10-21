# The old root module managed a single routed network (routed_network_* variables).
# This unit replaces it. Rename the folder to the real network name; the state key
# follows the folder path, so rename it BEFORE the state migration.
# For more networks, copy this folder (one unit per network).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/routed_network.hcl"
}

# org and edge_gateway_id (from ../../edge-gateway) are wired in _envcommon/routed_network.hcl.
inputs = {
  name           = "TODO" # was routed_network_name
  description    = "TODO" # was routed_network_description
  interface_type = "TODO" # was routed_network_interface_type
  gateway        = "TODO" # was routed_network_gateway
  prefix_length  = "TODO" # was routed_network_prefix_length
  dns1           = "TODO" # was routed_network_dns1
  dns2           = "TODO" # was routed_network_dns2

  # Not set in terraform.tfvars; the old root and module defaults agree:
  # dns_suffix = null, static_ip_pools = [], dhcp_pool = null (no vcd_nsxt_network_dhcp).
}
