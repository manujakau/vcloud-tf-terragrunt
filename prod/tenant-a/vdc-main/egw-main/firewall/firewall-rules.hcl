# Firewall rule data for edge gateway egw-main, read by ./terragrunt.hcl.
#
# Ordered list: rules are evaluated top to bottom. Unmatched traffic hits the
# gateway's default deny rule. Rule names must be unique. The module keys IP
# sets and custom port profiles by rule name, so renaming a rule replaces them.
#
# Fields: name, action (ALLOW|DROP|REJECT, default ALLOW),
# direction (IN|OUT|IN_OUT, default IN_OUT), ip_protocol (IPV4|IPV6|IPV4_IPV6),
# enabled, logging, source_ip_addresses, destination_ip_addresses,
# app_port_profiles (built-in names: "SSH", "HTTP", "HTTPS", "ICMP ALL", ...),
# custom_ports ([{ protocol = "tcp", ports = ["8080"] }]). Empty lists = any.
#
# Shape example:
#   rules = [
#     {
#       name                     = "allow-ssh-in"
#       direction                = "IN"
#       destination_ip_addresses = ["10.0.1.0/24"]
#       app_port_profiles        = ["SSH"]
#     },
#   ]
#
# An empty list ([]) removes the vcd_nsxt_firewall resource, which deletes all
# rules on the gateway.
locals {
  # Replace with the firewall_rules list from terraform.tfvars, keeping the order.
  rules = [
    { name = "TODO" },
  ]
}
