locals {
  # ------------------------------------------
  # Constants
  # ------------------------------------------
  wan_pppoe_type         = "pppoe"
  port_role_trunk        = "trunk_port"
  port_role_access       = "access_port"
  frame_type_trunk       = "admit-only-vlan-tagged"
  frame_type_access_port = "admit-only-untagged-and-priority-tagged"
  wireless_smips_pkg     = "wireless"
  wireless_not_smips_pkg = "wifiwave2"
  device_mode_router     = "router"
  device_mode_switch     = "switch"

  # ------------------------------------------
  # WLAN
  # ------------------------------------------
  # Device information
  system_architecture = data.routeros_system_resource.routeros_system_resource.architecture_name
  system_version      = data.routeros_system_routerboard.routeros_installed_firmware.current_firmware

  # Package handling
  # - smips + legacy radios => wireless
  # - arm/arm64 + newer radios => wifiwave2
  wifi_package  = local.system_architecture == "smips" ? local.wireless_smips_pkg : local.wireless_not_smips_pkg
  wifi_npk_name = "${local.wifi_package}-${local.system_version}-${local.system_architecture}.npk"
  device_interface_names = [
    for device_iface in data.routeros_interfaces.interfaces.interfaces :
    device_iface.name
  ]
  # If at least one expected WLAN interface exists, the package is considered installed
  has_wlan_interface = anytrue([
    for iface in var.default_wlan_interfaces :
    contains(local.device_interface_names, iface)
  ])
  install_wifi_package = var.verify_wifi_interfaces_present_install && !local.has_wlan_interface

  # ------------------------------------------
  # WAN
  # ------------------------------------------
  wan_interface_nic = one([for k, iface in var.ethernet_interfaces : k if try(iface.is_wan, false)])
  wan_settings      = var.ethernet_interfaces[local.wan_interface_nic].wan

  # ------------------------------------------
  # Ethernet Interfaces
  # ------------------------------------------
  # Flatten per-interface VLAN declarations into individual entries
  interface_vlan_entries = flatten([
    for iface_key, iface in var.ethernet_interfaces :
    iface.vlan != null ? (
      iface.vlan.role == local.port_role_trunk ? [
        for vlan_name in iface.vlan.tagged : {
          bridge_port = iface.bridge_port
          vlan_name   = vlan_name
          interface   = try(iface.name, iface_key)
          role        = iface.vlan.role
          frame_type  = local.frame_type_trunk
          pvid        = null
        }
      ] :
      [
        {
          vlan_name   = iface.vlan.untagged
          bridge_port = iface.bridge_port
          interface   = try(iface.name, iface_key)
          role        = iface.vlan.role
          frame_type  = local.frame_type_access_port
          pvid        = try(var.vlans[iface.vlan.untagged].pvid, null)
        }
      ]
    ) : []
  ])

  # ------------------------------------------
  # VLANs
  # ------------------------------------------
  # Unique VLAN names referenced by interfaces
  vlan_from_interfaces = distinct([for ethernet in local.interface_vlan_entries : ethernet.vlan_name])

  # * create a map of VLAN keys (names) defined.
  # * and compile which VLANs are referenced by an ethernet interface BUT not defined in VLANs.
  # * compile vlans defined but not used in any ethernet interface
  # these will be used later to fail terraform at early if a vlan is referenced but not declared
  vlan_names_defined = keys(var.vlans)
  undefined_vlans    = length(setsubtract(local.vlan_from_interfaces, local.vlan_names_defined)) > 0 ? sort(setsubtract(local.vlan_from_interfaces, local.vlan_names_defined)) : []
  unused_vlans       = length(setsubtract(local.vlan_names_defined, local.vlan_from_interfaces)) > 0 ? sort(setsubtract(local.vlan_names_defined, local.vlan_from_interfaces)) : []

  # Build a ports list grouped by vlan_name
  vlan_ports_map = {
    for vlan_name in local.vlan_from_interfaces : vlan_name => [
      for port in local.interface_vlan_entries : {
        interface  = port.interface
        role       = port.role
        frame_type = port.frame_type
        pvid       = port.pvid
      } if port.vlan_name == vlan_name
    ]
  }

  # Render the VLAN objects by merging interface-driven ports with var.vlans (DHCP/cidr/etc)
  vlans_rendered = {
    for vlan_name in local.vlan_from_interfaces : vlan_name => {
      # Base VLAN metadata
      name = format(
        "VLAN%d_%s",
        try(var.vlans[vlan_name].pvid, 0),
        upper(vlan_name)
      )
      internet_access = try(var.vlans[vlan_name].internet_access, false)
      pvid            = try(var.vlans[vlan_name].pvid, 0)
      cidr            = try(var.vlans[vlan_name].cidr, null)
      ports           = try(local.vlan_ports_map[vlan_name], [])

      dhcp = {
        enabled = try(var.vlans[vlan_name].dhcp.enabled, false)

        config = (
          try(var.vlans[vlan_name].dhcp.enabled, false)
          && try(var.vlans[vlan_name].cidr, null) != null
          ) ? {
          gateway   = cidrhost(var.vlans[vlan_name].cidr, 1)
          pool_name = "POOL_${upper(vlan_name)}"
          pool_range = format(
            "%s-%s",
            cidrhost(var.vlans[vlan_name].cidr, try(var.vlans[vlan_name].dhcp.pool_range_start, 2)),
            cidrhost(var.vlans[vlan_name].cidr, try(var.vlans[vlan_name].dhcp.pool_range_end, -2))
          )
          dhcp_server = "DHCP_${upper(vlan_name)}"
          network     = try(var.vlans[vlan_name].cidr, null)
          dns_server  = try(var.vlans[vlan_name].dns_server_ips, null)
        } : null
      }
    }
  }

  # Generate set with vlans that require DHCP usage
  vlan_dhcp_clients = var.configure_vlans ? toset([
    for _, vlan in local.vlans_rendered : vlan.name
    if vlan.dhcp.enabled
  ]) : toset([])
  # Generate set with vlans that require Internet access
  vlan_internet_access = var.configure_vlans ? toset([
    for _, vlan in local.vlans_rendered : vlan.name
    if vlan.internet_access
  ]) : toset([])

  # Bridge ports
  bridge_ports_vlan_rendered = {
    for iface, ports in {
      for port in flatten([
        for _, vlan in local.vlans_rendered : [
          for p in vlan.ports : merge(p, {
            bridge = var.vlan_bridge_name
          })
        ]
      ]) :
      port.interface => {
        bridge     = port.bridge
        interface  = port.interface
        role       = port.role
        frame_type = port.frame_type
        pvid       = port.pvid
      }...
      # The '...' operator allows multiple values with the same key to be merged into a list,
      # preventing duplicate key errors when an interface appears in multiple VLANs
    } :
    iface => (
      length([for port in ports : port if port.pvid != null]) > 0
      ? one([for port in ports : port if port.pvid != null])
      : ports[0]
    )
  }
}