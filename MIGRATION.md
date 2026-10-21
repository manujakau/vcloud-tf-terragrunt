# State migration: root module → per-unit Terragrunt states (DRAFT)

Status: **draft, not executed.** Nothing in this document has been run.
The old root state has not been read; the address table below is derived from
the module code and must be checked against `terraform state list` (step 3).

Goal: move every resource from the single local state of the old root module
(`vcloud-tf-moduler/terraform.tfstate`) into the per-unit S3 states of this repo
**without changing any real infrastructure**.

Exit criterion: **every unit plans with no changes** (step 8).

---

## 0. Prerequisites (all must be true before starting)

- [ ] Catalog tag `v1.0.0` exists and points at module code identical to the
      code that built the current state (modules are unchanged since `b492773`).
- [ ] Every `"TODO` placeholder in this repo is filled with the values from
      `terraform.tfvars`. `plan`/`apply` refuse to run otherwise.
- [ ] `networks/example-net/` is renamed to the real network name. The state key
      is the folder path, so renaming after the push means moving state again.
- [ ] The state bucket exists, versioning is enabled, and `AWS_ACCESS_KEY_ID` /
      `AWS_SECRET_ACCESS_KEY` can write to it.
- [ ] The object store honours conditional writes (required by `use_lockfile`).
      Test it directly against the bucket, without Terraform:
      ```bash
      aws --endpoint-url "$S3_ENDPOINT" s3api put-object --bucket <bucket> --key locktest --body /dev/null --if-none-match '*'   # succeeds
      aws --endpoint-url "$S3_ENDPOINT" s3api put-object --bucket <bucket> --key locktest --body /dev/null --if-none-match '*'   # must fail: 412 PreconditionFailed
      aws --endpoint-url "$S3_ENDPOINT" s3api delete-object --bucket <bucket> --key locktest
      ```
- [ ] Baseline: the **old root** plans with no changes (`terraform plan` in
      `vcloud-tf-moduler`). If it does not, fix the drift first. Otherwise you
      cannot tell migration diffs from pre-existing drift.

## 1. Freeze

- Announce a change window. Nobody runs `apply` on the old root from here on.
- Disable any CI job that plans or applies the old root.

## 2. Back up first

Work only on copies. The original `terraform.tfstate` is never modified.

```bash
cd vcloud-tf-moduler
ts=$(date +%Y%m%d-%H%M%S)
mkdir -p ~/vcd-state-backup/$ts
terraform state pull > ~/vcd-state-backup/$ts/root.tfstate     # same content as terraform.tfstate (local backend)
cp terraform.tfstate terraform.tfstate.backup ~/vcd-state-backup/$ts/
( cd ~/vcd-state-backup/$ts && sha256sum * > SHA256SUMS )
```

- The state may contain sensitive values. Store the backup encrypted and off
  this machine (e.g. a separate, versioned bucket). Don't put it in git.
- Verify the backup is readable:
  `terraform state list -state=$HOME/vcd-state-backup/$ts/root.tfstate | wc -l`

## 3. Inventory

```bash
terraform state list > ~/vcd-state-backup/$ts/addresses.txt
```

Compare with the table below. **Stop if any address is not covered.**

| Old address (root state)                                          | Unit (under `prod/tenant-a/`)               | New address |
|-------------------------------------------------------------------|---------------------------------------------|-------------|
| `module.org.vcd_org.this`                                         | `org`                                       | `vcd_org.this` |
| `module.vdc.vcd_org_vdc.this`                                     | `vdc-main/vdc`                              | `vcd_org_vdc.this` |
| `module.edge_gateway.vcd_nsxt_edgegateway.this`                   | `vdc-main/egw-main/edge-gateway`            | `vcd_nsxt_edgegateway.this` |
| `module.routed_network.vcd_network_routed_v2.this`                | `vdc-main/egw-main/networks/<name>`         | `vcd_network_routed_v2.this` |
| `module.routed_network.vcd_nsxt_network_dhcp.this[0]` (only if DHCP) | `vdc-main/egw-main/networks/<name>`      | `vcd_nsxt_network_dhcp.this[0]` |
| `module.firewall_rules.vcd_nsxt_firewall.this[0]`                 | `vdc-main/egw-main/firewall`                | `vcd_nsxt_firewall.this[0]` |
| `module.firewall_rules.vcd_nsxt_ip_set.this["<rule>-src|dst"]`    | `vdc-main/egw-main/firewall`                | `vcd_nsxt_ip_set.this["<rule>-src|dst"]` |
| `module.firewall_rules.vcd_nsxt_app_port_profile.custom["<rule>"]`| `vdc-main/egw-main/firewall`                | `vcd_nsxt_app_port_profile.custom["<rule>"]` |
| `module.nat_rules.vcd_nsxt_nat_rule.dnat["<key>"]`                | `vdc-main/egw-main/nat`                     | `vcd_nsxt_nat_rule.dnat["<key>"]` |
| `module.nat_rules.vcd_nsxt_nat_rule.snat["<key>"]`                | `vdc-main/egw-main/nat`                     | `vcd_nsxt_nat_rule.snat["<key>"]` |
| `module.*.data.*`                                                 | not moved                                    | re-read by each unit |

The new address is always the old address with the `module.<name>.` prefix
removed, because each unit runs the same module as its root.

---

## Option A (recommended): split with `state mv`, then `state push`

This moves the stored objects unchanged. Attributes that VCD does not return
on read, such as `vcd_org_vdc.delete_force` / `delete_recursive`, keep their
values, so the first plan should be empty.

### 4A. Split the copy into one file per unit

Run from `vcloud-tf-moduler`. It is still initialised with the local backend,
which the `-state` / `-state-out` flags require.

```bash
W=~/vcd-state-backup/$ts/work
mkdir -p $W && cp ~/vcd-state-backup/$ts/root.tfstate $W/work.tfstate

split_unit() {   # split_unit <module-name> <output-file>
  grep "^module\.$1\." ~/vcd-state-backup/$ts/addresses.txt | grep -v "^module\.$1\.data\." |
  while IFS= read -r addr; do
    terraform state mv -state="$W/work.tfstate" -state-out="$W/$2" "$addr" "${addr#module.$1.}"
  done
}

split_unit org            org.tfstate
split_unit vdc            vdc.tfstate
split_unit edge_gateway   edge-gateway.tfstate
split_unit routed_network network.tfstate
split_unit firewall_rules firewall.tfstate
split_unit nat_rules      nat.tfstate

# Only data sources may remain in the work copy:
terraform state list -state="$W/work.tfstate"
for f in $W/*.tfstate; do echo "== $f"; terraform state list -state="$f"; done
```

Check that every non-data line of `addresses.txt` appears in exactly one per-unit file.

### 5A. Push, one unit at a time, in dependency order

Order: `org` → `vdc` → `edge-gateway` → `networks/<name>` → `firewall` → `nat`.
Finish steps a–f for a unit before starting its dependents.

```bash
cd vcloud-live/prod/tenant-a/org        # then vdc-main/vdc, ... (see order above)
terragrunt init
terragrunt state list                    # a. must be EMPTY. If not, stop
terragrunt state push $W/org.tfstate     # b.
terragrunt state list                    # c. must match the per-unit file
terragrunt plan                          # d. no resource changes. Only "Changes to Outputs" are expected
terragrunt apply -refresh-only           # e. review: it should only add outputs; then confirm
terragrunt plan -detailed-exitcode       # f. exit code 0
```

Why step e: the pushed state has resources but no root outputs (those belonged
to the old root). Until the outputs are written, dependent units fall back to
`mock_outputs` on `plan`. Their plans would then show bogus replacements, and
`apply` is blocked. Don't act on a dependent's plan until every dependency has passed step f.

If step d shows any resource change, stop. Compare the unit inputs with
`terraform.tfvars` (the usual suspects are `storage_profile` order or flags,
`delete_*`, rule order, map keys), fix the inputs and re-plan. Never apply a
resource change during the migration.

---

## Option B (fallback): `import` blocks + `removed` blocks

Use this only if Option A is not possible, e.g. the state is corrupted or you
want to re-derive state from VCD.

1. In each unit, add a temporary Terragrunt `generate "imports"` block that writes
   `import { to = <new address>  id = "<import id>" }` for every resource in the table.
   Look up the import ID format in the *Importing* section of each resource's
   vcd provider 3.14 documentation. Most are dot-separated paths such as
   `org.vdc.edge-gateway[.name]`. NAT rules are looked up by name, so rule names
   must be unique on the gateway.
2. `terragrunt plan` per unit: only `import` actions are allowed. Expect in-place
   updates for attributes VCD doesn't return (`delete_force`, `delete_recursive`).
   They are state-only and safe, but check each one.
3. `terragrunt apply` to record the imports, then remove the generate block.
4. In the old root, add `removed { from = module.<name>  lifecycle { destroy = false } }`
   for every module (Terraform >= 1.7) and `terraform apply`. **Never** delete the
   module blocks without `removed` blocks: Terraform would plan a destroy.

---

## 8. Exit check: every unit plans with no changes

```bash
cd vcloud-live/prod
terragrunt run --all -- plan -detailed-exitcode
echo $?        # must be 0 (any unit with changes returns 2)
```

All of these must hold:

- [ ] `run --all plan` exits 0 and every unit reports *No changes*.
- [ ] No unit used mock outputs. Every dependency has real outputs (`terragrunt output` in each dependency).
- [ ] The work copy contains only data sources (Option A), or the old root's
      `terraform state list` is empty (Option B).
- [ ] The state lock works: a second concurrent `terragrunt plan` on the same unit
      waits for or fails on the lock.

## 9. Retire the old root

- Archive `terraform.tfstate*` from `vcloud-tf-moduler` to the backup location,
  then remove them from the working copy. Keep the backup for at least one release cycle.
- In the catalog, delete `main.tf`, `variables.tf`, `outputs.tf`, root `versions.tf`
  and `terraform.tfvars.example`. Release that as a new version (breaking for
  anyone still using the root module, so `v2.0.0` is appropriate).
- Re-enable CI, now against this repo.

## Rollback

Until step 9, rollback means continuing to use the old root. Its configuration
and the original `terraform.tfstate` are never modified by this procedure.

- Delete the per-unit state objects (or the whole `prod/` prefix) from the bucket.
- If an `apply` other than `-refresh-only` ran in any unit, real infrastructure may
  have changed. Run the old root's `terraform plan` and reconcile before you resume.
