# ------------------------------------------
# Ethernet
# ------------------------------------------
resource "routeros_interface_ethernet" "eth" {
  for_each = var.ethernet_interfaces

  factory_name = each.key
  name         = each.key

  comment  = try(each.value.comment, null)
  disabled = try(each.value.disabled, null)

  # MTU
  mtu   = try(each.value.mtu.mtu, null)
  l2mtu = try(each.value.mtu.l2mtu, null)

  # Link / speed
  auto_negotiation = try(each.value.link.auto_negotiation, null)
  advertise        = try(each.value.link.advertise, null)
  speed            = try(each.value.link.speed, null)
  full_duplex      = try(each.value.link.full_duplex, null)
  mdix_enable      = try(each.value.link.mdix_enable, null)
  combo_mode       = try(each.value.link.combo_mode, null)
  fec_mode         = try(each.value.link.fec_mode, null)

  # ARP
  arp         = try(each.value.arp.mode, null)
  arp_timeout = try(each.value.arp.timeout, null)
  mac_address = try(each.value.arp.mac_address, null)

  # Flow control
  rx_flow_control = try(each.value.flow_control.rx, null)
  tx_flow_control = try(each.value.flow_control.tx, null)

  # Loop protection
  loop_protect               = try(each.value.loop_protect.mode, null)
  loop_protect_disable_time  = try(each.value.loop_protect.disable_time, null)
  loop_protect_send_interval = try(each.value.loop_protect.send_interval, null)

  # Bandwidth
  bandwidth = try(each.value.bandwidth, null)

  # SFP
  sfp_ignore_rx_los        = try(each.value.sfp.ignore_rx_los, null)
  sfp_rate_select          = try(each.value.sfp.rate_select, null)
  sfp_shutdown_temperature = try(each.value.sfp.shutdown_temperature, null)

  # PoE
  poe_out          = try(each.value.poe.out, null)
  poe_priority     = try(each.value.poe.priority, null)
  poe_voltage      = try(each.value.poe.voltage, null)
  poe_lldp_enabled = try(each.value.poe.lldp_enabled, null)

  # Power cycling
  power_cycle_interval     = try(each.value.power_cycle.interval, null)
  power_cycle_ping_address = try(each.value.power_cycle.ping_address, null)
  power_cycle_ping_enabled = try(each.value.power_cycle.ping_enabled, null)
  power_cycle_ping_timeout = try(each.value.power_cycle.ping_timeout, null)

  # Advanced
  disable_running_check = try(each.value.advanced.disable_running_check, null)
  cable_settings        = try(each.value.advanced.cable_settings, null)
}

# ------------------------------------------
# WLAN
# (package) detection/installation
# ------------------------------------------
resource "null_resource" "download_wifi_npk" {
  count = var.configure_wlan_interfaces.enable_wlan && local.install_wifi_package ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      chmod +x ./helper/download_routeros_packages.sh
      ./helper/download_routeros_packages.sh ${local.system_architecture} "${local.system_version}" "${local.wifi_package}"
    EOT
  }
}
resource "null_resource" "upload_wifi_npk" {
  count = var.configure_wlan_interfaces.enable_wlan && local.install_wifi_package ? 1 : 0

  provisioner "local-exec" {
    command = "scp -i ${var.admin_user_credentials.name} \"/tmp/routeros_packages/${local.wifi_npk_name}\" ${var.admin_user_credentials.ssh_key}@${var.device_mgmt_ip}:/${local.wifi_npk_name}"
  }

  depends_on = [null_resource.download_wifi_npk]
}
resource "null_resource" "install_wifi_npk" {
  count = var.configure_wlan_interfaces.enable_wlan && local.install_wifi_package ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      ssh -i ${var.admin_user_credentials.ssh_key} ${var.admin_user_credentials.name}@${var.device_mgmt_ip} '/system reboot; sleep 5'
      until ssh -i ${var.admin_user_credentials.ssh_key} -o ConnectTimeout=2 ${var.admin_user_credentials.name}@${var.device_mgmt_ip} ':put ready' 2>/dev/null
      do
        echo "Waiting for device to reboot and become available..."
        sleep 10
      done
    EOT
  }

  depends_on = [null_resource.upload_wifi_npk]
}