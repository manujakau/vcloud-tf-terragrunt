# Root Terragrunt configuration. Every unit includes it with:
#
#   include "root" {
#     path = find_in_parent_folders("root.hcl")
#   }
#
# Required environment variables (never commit their values):
#   VCD_USER, VCD_PASSWORD                      System administrator credentials for the vcd provider
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY    Credentials for the S3-compatible state bucket

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform_binary              = "terraform"
terraform_version_constraint  = ">= 1.11" # S3 backend use_lockfile is GA from 1.11
terragrunt_version_constraint = ">= 1.0"

remote_state {
  backend = "s3"

  # Offline validation (CI, no access to the bucket): run with
  # TF_CLI_ARGS_init=-backend=false. Never set it for plan/apply.

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = "TODO-state-bucket"
    key    = "${path_relative_to_include()}/terraform.tfstate"

    # S3-compatible endpoint (e.g. MinIO). region is still required by the S3
    # backend; eu-central-1 is MinIO's default unless the server sets its own region.
    endpoints      = { s3 = "TODO-https://minio.example.internal:9000" }
    region         = "eu-central-1"
    use_path_style = true

    # Native S3 locking: a <key>.tflock object written with a conditional PUT
    # (If-None-Match). The object store MUST support conditional writes, or two
    # concurrent runs can both acquire the lock. No DynamoDB table is used.
    use_lockfile = true

    # A non-AWS endpoint has no STS/IAM/EC2 metadata and may not support the
    # AWS checksum headers, so skip those calls.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true

    # Terragrunt-only settings: never try to apply AWS-specific bucket
    # hardening (versioning, SSE, TLS policy, public access block) to the
    # bucket. Enable versioning on the bucket in MinIO directly.
    skip_bucket_versioning             = true
    skip_bucket_ssencryption           = true
    skip_bucket_root_access            = true
    skip_bucket_enforced_tls           = true
    skip_bucket_public_access_blocking = true
    disable_bucket_update              = true
  }
}

# The modules declare required_providers but no provider block. Credentials
# are passed as inputs (TF_VAR_* environment variables at run time), so they
# never appear in the generated provider.tf or anywhere else on disk.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "vcd_url" {
      type = string
    }

    variable "vcd_user" {
      type      = string
      sensitive = true
    }

    variable "vcd_password" {
      type      = string
      sensitive = true
    }

    # All resources in this stack require System Administrator privileges.
    provider "vcd" {
      url      = var.vcd_url
      user     = var.vcd_user
      password = var.vcd_password
      org      = "System"
    }
  EOF
}

terraform {
  # Refuse to plan/apply while a TODO placeholder string is left in the unit,
  # its data files, org.hcl or env.hcl. validate is allowed. (This file is not
  # scanned; the TODO bucket/endpoint above already make init fail.)
  before_hook "refuse_todo_placeholders" {
    commands = ["plan", "apply"]
    execute = concat(
      [
        "sh", "-c",
        "if grep -Hn '\"TODO' \"$@\"; then echo 'ERROR: fill in the TODO placeholders listed above before plan/apply' >&2; exit 1; fi",
        "todo-guard",
        find_in_parent_folders("env.hcl"),
        find_in_parent_folders("org.hcl", find_in_parent_folders("env.hcl")),
      ],
      [for f in fileset(get_terragrunt_dir(), "*.hcl") : "${get_terragrunt_dir()}/${f}"],
    )
  }
}

inputs = {
  # The URL comes from env.hcl, so each environment always targets its own VCD.
  vcd_url = local.env_vars.locals.vcd_url

  # get_env() without a default fails fast when the variable is unset.
  vcd_user     = get_env("VCD_USER")
  vcd_password = get_env("VCD_PASSWORD")
}
