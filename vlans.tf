# ------------------------------------------
# VLAN Bridge - INGRESS
# ------------------------------------------
resource "routeros_interface_bridge" "vlan_bridge" {
  count = var.create_vlan_bridge_interface ? 1 : 0

  name           = var.vlan_bridge_name
  vlan_filtering = true
}
resource "routeros_interface_bridge_port" "vlan_bridge_port" {
  for_each = var.configure_vlans ? local.bridge_ports_vlan_rendered : {}

  bridge      = routeros_interface_bridge.vlan_bridge[0].name
  interface   = each.value.interface
  hw          = true
  frame_types = each.value.frame_type
  pvid        = each.value.pvid
}

# Bridge VLANs (tagging configuration)
resource "routeros_interface_bridge_vlan" "vlan_bridge_vlan" {
  for_each = var.configure_vlans ? local.vlans_rendered : {}

  bridge   = routeros_interface_bridge.vlan_bridge[0].name
  vlan_ids = [lookup(each.value, "pvid")]

  tagged = distinct(concat
    (
      # tag bridge iface too since vlans need IP Services (L3)
      [var.vlan_bridge_name],
      [
        for port in lookup(each.value, "ports", []) :
        lookup(port, "interface", "") if lookup(port, "role", "") == local.port_role_trunk
      ]
    )
  )
  untagged = [
    for port in lookup(each.value, "ports", []) :
    lookup(port, "interface", "") if lookup(port, "role", "") != local.port_role_trunk
  ]
}

# ------------------------------------------
# VLANs SVI Entries - EGRESS
# ------------------------------------------
resource "routeros_interface_vlan" "interface_vlan" {
  for_each = var.configure_vlans ? local.vlans_rendered : {}

  interface = routeros_interface_bridge.vlan_bridge[0].name
  name      = lookup(each.value, "name", "")
  vlan_id   = lookup(each.value, "pvid")
}

# ------------------------------------------
# IP Services
# ------------------------------------------
resource "routeros_ip_address" "vlan_address" {
  for_each = var.configure_vlans && var.device_mode == local.device_mode_router ? local.vlans_rendered : {}

  address   = lookup(each.value, "cidr", null)
  interface = lookup(each.value, "name", "")

  depends_on = [routeros_interface_vlan.interface_vlan]
}
resource "routeros_ip_pool" "vlan_pool_addr" {
  for_each = var.configure_vlans && var.device_mode == local.device_mode_router ? {
    for vlan_key, vlan in local.vlans_rendered : vlan_key => vlan if lookup(vlan, "dhcp", {}).enabled
  } : {}

  name   = lookup(each.value.dhcp.config, "pool_name", "POOL_DEFAULT")
  ranges = [lookup(each.value.dhcp.config, "pool_range", "0.0.0.0-0.0.0.0")]
}
resource "routeros_ip_dhcp_server" "vlan_dhcp_server" {
  for_each = var.configure_vlans && var.device_mode == local.device_mode_router ? {
    for vlan_key, vlan in local.vlans_rendered : vlan_key => vlan if lookup(vlan, "dhcp", {}).enabled
  } : {}

  name         = lookup(each.value.dhcp.config, "dhcp_server", "DHCP_DEFAULT")
  interface    = lookup(each.value, "name", "")
  address_pool = routeros_ip_pool.vlan_pool_addr[each.key].name

  depends_on = [
    routeros_interface_vlan.interface_vlan,
    routeros_ip_pool.vlan_pool_addr
  ]
}
resource "routeros_ip_dhcp_server_network" "vlan_dhcp_server_network" {
  for_each = var.configure_vlans && var.device_mode == local.device_mode_router ? {
    for vlan_key, vlan in local.vlans_rendered : vlan_key => vlan if lookup(vlan, "dhcp", {}).enabled
  } : {}

  address    = cidrsubnet(lookup(each.value.dhcp.config, "network", null), 0, 0)
  gateway    = lookup(each.value.dhcp.config, "gateway", null)
  dns_server = lookup(each.value.dhcp.config, "dns_server_ips", null)

  depends_on = [routeros_ip_dhcp_server.vlan_dhcp_server]
}

# ------------------------------------------
# VLAN Interface Lists
# ------------------------------------------
# VLANs that need DHCP
resource "routeros_interface_list" "vlan_dhcp_client_list_interface" {
  count = var.configure_vlans && var.device_mode == local.device_mode_router && length(local.vlan_dhcp_clients) > 0 ? 1 : 0

  name = var.lan_dhcp_clients_fw_addr_list_name
}
resource "routeros_interface_list_member" "vlan_dhcp_list_member" {
  for_each = var.configure_vlans && var.device_mode == local.device_mode_router && length(local.vlan_dhcp_clients) > 0 ? local.vlan_dhcp_clients : toset([])

  interface = each.value
  list      = routeros_interface_list.vlan_dhcp_client_list_interface[0].name

  depends_on = [routeros_interface_vlan.interface_vlan]
}
# VLANs that need Internet access
resource "routeros_interface_list" "vlan_internet_access_list_interface" {
  count = var.configure_vlans && var.device_mode == local.device_mode_router && length(local.vlan_internet_access) > 0 ? 1 : 0

  name = var.lan_internet_clients_fw_addr_list_name
}
resource "routeros_interface_list_member" "vlan_internet_list_member" {
  for_each = var.configure_vlans && var.device_mode == local.device_mode_router && length(local.vlan_internet_access) > 0 ? local.vlan_internet_access : toset([])

  interface = each.value
  list      = routeros_interface_list.vlan_internet_access_list_interface[0].name

  depends_on = [routeros_interface_vlan.interface_vlan]
}