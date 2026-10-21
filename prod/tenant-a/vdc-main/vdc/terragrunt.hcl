include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vdc.hcl"
}

# org comes from org.hcl; the ordering dependency on ../../org is in _envcommon/vdc.hcl.
inputs = {
  name              = "TODO" # was vdc_name
  description       = "TODO" # was vdc_description
  network_pool_name = "TODO" # was vdc_network_pool_name
  provider_vdc_name = "TODO" # was vdc_provider_vdc_name

  # was vdc_allocation_model. The old root validated this, but the module does not:
  # use exactly one of AllocationVApp, AllocationPool, ReservationPool, Flex.
  allocation_model = "TODO"
  cpu_allocated    = "TODO" # was vdc_cpu_allocated (MHz)
  memory_allocated = "TODO" # was vdc_memory_allocated (MB)

  # was vdc_storage_profile: one object per profile, in the same order.
  # The old root made `default` and `enabled` optional (default true), but the
  # module requires all four fields. They are set explicitly here so the unit
  # keeps the old behaviour regardless of module defaults. terraform.tfvars sets
  # them explicitly, so copy them from there; if a profile omits them, use true.
  storage_profile = [
    {
      name    = "TODO"
      limit   = "TODO"
      default = "TODO"
      enabled = "TODO"
    },
  ]

  enable_thin_provisioning = "TODO" # was vdc_enable_thin_provisioning
  enable_fast_provisioning = "TODO" # was vdc_enable_fast_provisioning
  network_quota            = "TODO" # was vdc_network_quota (0 = no networks, not unlimited)

  # The old root module defaulted these to true; the module defaults them to
  # false. They are set explicitly so that (a) the state migration plans with no
  # changes and (b) destroying this unit still removes the VDC together with any
  # remaining contents, exactly as the old stack did. Set them to false if you
  # want VCD to refuse to delete a non-empty VDC.
  delete_force     = true
  delete_recursive = true

  # Not set in terraform.tfvars; the old root and module defaults agree:
  # nic_quota = 0, vm_quota = 0, memory_guaranteed = null, cpu_guaranteed = null, enabled = true.
}
