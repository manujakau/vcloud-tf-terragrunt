# vcloud-live

Terragrunt live configuration for VMware Cloud Director. This repo holds no
`.tf` files. Every unit pins a module from the catalog repo
(`git@github.com:manujakau/vcloud-tf-modeler.git//modules/<name>?ref=<module_version>`).

## Layout

```
root.hcl            remote state (S3-compatible, key = unit path) + vcd provider (org = "System")
_envcommon/         per-module source URL + common wiring (dependencies, org name)
prod/
  env.hcl           vcd_url, module_version
  tenant-a/
    org.hcl         org_name (read by every unit below it)
    org/
    vdc-main/
      vdc/          depends on ../../org (ordering only)
      egw-main/
        edge-gateway/   needs vdc_id
        firewall/       needs vdc_id + gateway_id. The ONLY firewall unit for this gateway
        nat/            needs vdc_id + gateway_id
        networks/<name>/  needs gateway_id. One unit per network
```

## Requirements

- Terraform >= 1.11 (`terraform_binary = "terraform"` in root.hcl), Terragrunt >= 1.0
- SSH access to the catalog repo (git source)
- Environment variables (never commit them):

  | Variable | Used by |
  |----------|---------|
  | `VCD_USER`, `VCD_PASSWORD` | vcd provider (System administrator), passed as `TF_VAR_*` inputs |
  | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | S3 backend (MinIO access key) |

The VCD URL is taken from `env.hcl`, not from `VCD_URL`.

## Usage

```bash
cd prod
terragrunt run --all plan
terragrunt run --all apply      # org -> vdc -> edge-gateway -> {networks, firewall, nat}
```

`plan` and `apply` refuse to run while any `"TODO` placeholder value remains in a
unit, its data files, `org.hcl` or `env.hcl`.

## Offline checks

```bash
terragrunt hcl fmt --check

# With the state bucket reachable (nothing applied yet), mocks are used automatically:
terragrunt run --all validate

# Fully offline (no bucket, no VCD; credentials only need to be set, not valid):
#   -backend=false              skip backend init
#   --no-dependency-outputs     don't call `terraform output` on dependencies; use mock_outputs
#                               (experiment flag in Terragrunt 1.1)
TF_CLI_ARGS_init=-backend=false VCD_USER=x VCD_PASSWORD=x \
  terragrunt run --all --experiment optional-dependency-outputs --no-dependency-outputs -- validate
```

To validate against unreleased catalog code instead of the git tag, export the
tracked files and pass them with `--source`. Don't point `--source` at a working
copy that contains `terraform.tfvars` / `terraform.tfstate`: Terragrunt copies the
whole directory into every `.terragrunt-cache`.

```bash
mkdir -p /tmp/catalog && git -C ../vcloud-tf-moduler archive HEAD modules | tar -x -C /tmp/catalog
TF_CLI_ARGS_init=-backend=false VCD_USER=x VCD_PASSWORD=x \
  terragrunt run --all --experiment optional-dependency-outputs --no-dependency-outputs \
  --source /tmp/catalog -- validate
```

## Caveats

- **Mocks do not help data sources.** `firewall_rules` and `nat_rules` look up
  built-in application port profiles with `context_id = vdc_id`. On a first-time
  `plan`, before the VDC exists, the mocked `vdc_id` is sent to VCD and the lookup
  fails. This only happens when a rule uses `app_port_profiles` / `app_port_profile`.
  `edge_gateway` looks up the external network by name, which needs VCD access
  but no upstream output. Apply in dependency order, or plan downstream units
  after their dependencies exist.
- NAT addresses are plain inputs. Keep them in step with the edge gateway's
  `allocated_ips` and the network CIDRs.
- Upgrading modules: bump `module_version` in `env.hcl` once the tag exists in the catalog.
