# Environment-wide settings for prod. Read by root.hcl and _envcommon/*.hcl.
locals {
  vcd_url = "TODO-https://vcd.example.com/api" # was vcd_url in terraform.tfvars

  # Catalog tag that every prod unit pins (git::...//modules/<name>?ref=<this>).
  module_version = "v1.0.0"
}
