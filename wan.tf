# ------------------------------------------
# WAN
# ------------------------------------------
resource "routeros_interface_list" "wan_list_interface" {
  count = var.configure_wan_internet ? 1 : 0

  name = local.wan_settings.interface_list_name
}
resource "routeros_ip_dhcp_client" "wan_dhcp_client" {
  count = local.wan_settings.connection_type == "dhcp" && var.configure_wan_internet ? 1 : 0

  disabled     = false
  interface    = local.wan_interface_nic
  use_peer_ntp = false
  use_peer_dns = local.wan_settings.use_peer_dns
  comment      = "DHCP_${local.wan_settings.interface_list_name}_${local.wan_settings.isp_provider}"
}
resource "routeros_interface_pppoe_client" "pppoe_client" {
  count = local.wan_settings.connection_type == "pppoe" && var.configure_wan_internet ? 1 : 0

  interface         = local.wan_interface_nic
  name              = "pppoe-out1"
  comment           = try("PPPoE_${local.wan_settings.isp_provider}", "PPPoE_Client")
  add_default_route = true
  use_peer_dns      = local.wan_settings.use_peer_dns
  user              = var.wan_pppoe_credentials.username
  password          = var.wan_pppoe_credentials.password
  max_mtu           = local.wan_settings.pppoe_settings.max_mtu
  max_mru           = local.wan_settings.pppoe_settings.max_mru
}
resource "routeros_interface_list_member" "wan_list_member" {
  count = var.configure_wan_internet ? 1 : 0

  interface = local.wan_settings.connection_type == "pppoe" ? routeros_interface_pppoe_client.pppoe_client[0].name : local.wan_interface_nic
  list      = local.wan_settings.interface_list_name

  depends_on = [routeros_interface_list.wan_list_interface]
}
resource "routeros_interface_detect_internet" "detect_internet" {
  count = var.configure_wan_internet ? 1 : 0

  internet_interface_list = local.wan_settings.interface_list_name
  wan_interface_list      = local.wan_settings.interface_list_name
  lan_interface_list      = local.wan_settings.interface_list_name
  detect_interface_list   = local.wan_settings.interface_list_name

  depends_on = [routeros_interface_list.wan_list_interface]
}