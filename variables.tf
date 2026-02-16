# ------------------------------------------
# Control Flow
# ------------------------------------------
variable "configure_wan_internet" {
  description = "Whether to configure WAN (Internet) or not"
  type        = bool
  default     = false
}
variable "create_vlan_bridge_interface" {
  description = "Whether to create a Brdige interface for VLANs or not"
  type        = bool
  default     = false
}
variable "configure_vlans" {
  description = "Whether to configure VLANs or not"
  type        = bool
  default     = false
}
variable "verify_wifi_interfaces_present_install" {
  description = <<-EOT
    Whether to verify if the firmware for Wireless interfaces to work is installed or not.
    Would it not be present, it will automatically install it
  EOT
  type        = bool
  default     = false
}
variable "device_mode" {
  description = "Whether the device is being configured as a router or a switch"
  type        = string
  default     = "router"

  validation {
    condition = alltrue([
      (contains([local.device_mode_router, local.device_mode_switch], var.device_mode))
    ])
    error_message = "Invalid 'device_mode' configuration: mode can must be either 'router' or 'switch'"
  }
}

# ------------------------------------------
# WAN - PPPoE
# ------------------------------------------
variable "wan_pppoe_credentials" {
  description = "PPPoE client credentials"
  type = object({
    username = optional(string)
    password = optional(string)
  })
  sensitive = true
  default   = {}
}

# ------------------------------------------
# Network Interfaces
# ------------------------------------------
# 'ethernet_interfaces' variable taken and adapted from:
# * https://github.com/mirceanton/mikrotik-terraform/blob/11524186be62b4145b513c8cfe7db581b75d108e/modules/mikrotik-base/_variables.tf#L105
variable "ethernet_interfaces" {
  description = "A map containing all of the ethernet interfaces to be configured"
  type = map(object({
    is_wan      = optional(bool, false)
    bridge_port = optional(bool, true)
    comment     = optional(string)
    bandwidth   = optional(string)
    disabled    = optional(bool)
    # For more information on MTU, check the official documentation
    # * https://help.mikrotik.com/docs/spaces/ROS/pages/21725296/MTU+in+RouterOS
    mtu = optional(object({
      mtu   = optional(number)
      l2mtu = optional(number)
    }))
    # For more information on Link, auto mode, force mode, etc. check the official documentation
    # * https://help.mikrotik.com/docs/spaces/ROS/pages/8323191/Ethernet#Ethernet-Auto-negotiationandForcedLinkMode
    link = optional(object({
      combo_mode       = optional(string)
      fec_mode         = optional(string)
      advertise        = optional(string)
      speed            = optional(string)
      auto_negotiation = optional(bool)
      full_duplex      = optional(bool)
      mdix_enable      = optional(bool)
    }))
    arp = optional(object({
      mode        = optional(string)
      timeout     = optional(string)
      mac_address = optional(string)
    }))
    flow_control = optional(object({
      rx = optional(string)
      tx = optional(string)
    }))
    loop_protect = optional(object({
      mode          = optional(string)
      disable_time  = optional(string)
      send_interval = optional(string)
    }))
    sfp = optional(object({
      rate_select          = optional(string)
      shutdown_temperature = optional(number)
      ignore_rx_los        = optional(bool)
    }))
    poe = optional(object({
      out          = optional(string)
      voltage      = optional(string)
      priority     = optional(number)
      lldp_enabled = optional(bool)
    }))
    power_cycle = optional(object({
      interval     = optional(string)
      ping_address = optional(string)
      ping_timeout = optional(string)
      ping_enabled = optional(bool)
    }))
    advanced = optional(object({
      cable_settings        = optional(string)
      disable_running_check = optional(bool)
    }))
    vlan = optional(object({
      role     = string
      tagged   = optional(list(string))
      untagged = optional(list(string))
    }))
    wan = optional(object({
      connection_type     = optional(string, "dhcp")
      use_peer_dns        = optional(bool, false)
      interface_list_name = optional(string)
      isp_provider        = optional(string)
      pppoe_settings = optional(object({
        # PPPoE settings to use when Internet Connection method is PPPoE.
        # For details regarding some of these settings, please refer to MikroTik's official
        # PPPoE documentation: https://help.mikrotik.com/docs/spaces/ROS/pages/2031625/PPPoE
        max_mtu = optional(number, 1460)
        max_mru = optional(number, 1460)

      }))
    }))
  }))
  default = {
    "ether1" = { comment = "WAN", is_wan = true, wan = { connection_type = "pppoe" } }
    "ether2" = { comment = "Disabled", disabled = true }
    "ether3" = { comment = "Disabled", disabled = true }
    "ether4" = { comment = "Disabled", disabled = true }
    "ether5" = { comment = "Disabled", disabled = true }
    "ether6" = { comment = "Disabled", disabled = true }
    "ether7" = { comment = "Disabled", disabled = true }
    "ether8" = { comment = "RED_IOT Access", vlan = { role = "access_port", untagged = ["RED_IOT"] }, mtu = { mtu = 1500 } }
    "sfp1"   = { comment = "Trunk Port SFP+", vlan = { role = "trunk_port", tagged = ["BLUE_OFFICE", "GREEN_TRUSTED"], untagged = ["BLACKHOLE"] } }
  }
  # TODO: Add validation blocks to check
  # * if 'is_wan' is true, only dhcp or pppoe accepted as connection_type (ideally is always required but enforce values)
  # * if 'is_wan' is true, do not allow wan = { interface_list_name } to be empty
  # * if 'is_wan' is true, and connection_type is NOT pppoe, do not allow definition of pppoe_settings
  validation {
    condition = length([
      for _, iface in var.ethernet_interfaces : iface.is_wan
      if iface.is_wan == true
    ]) <= 1
    error_message = "Invalid 'ethernet_interfaces': only one interface can be set as 'is_wan' = true"
  }
  validation {
    condition = alltrue([
      for _, iface in var.ethernet_interfaces :
      !(iface.is_wan == true && iface.vlan != null && length(keys(iface.vlan)) > 0)
    ])
    error_message = "Invalid 'ethernet_interfaces': a WAN interface ('is_wan' = true) cannot have VLAN's assigned"
  }
  validation {
    condition = alltrue([
      for _, iface in var.ethernet_interfaces :
      iface.vlan == null || (contains([local.port_role_trunk, local.port_role_access], iface.vlan.role))
    ])
    error_message = "Invalid VLAN configuration on 'ethernet_interfaces': role must be either 'access_port' or 'trunk_port'"
  }
}

# ------------------------------------------
# VLAN
# ------------------------------------------
variable "vlan_bridge_name" {
  description = "The name of the bridge interface VLANs use (with Hardware offloading)"
  type        = string
  default     = "BR_VLAN"
}
variable "vlans" {
  description = "Map of VLANs to configure"
  type = map(object({
    dns_server_ips  = optional(list(string))
    internet_access = optional(bool, false)
    cidr            = optional(string)
    pvid            = number
    dhcp = object({
      enabled          = bool
      pool_range_start = optional(number, 2)
      pool_range_end   = optional(number, -2)
    })
  }))
  default = {
    "BLUE" = {
      internet_access = true
      cidr            = "10.0.10.1/24"
      pvid            = 10
      dhcp = {
        enabled          = true
        pool_range_start = 2
        pool_range_end   = 254
      }
    }
    "GREEN" = {
      internet_access = true
      cidr            = "10.0.20.1/24"
      pvid            = 20
      dhcp = {
        enabled          = true
        pool_range_start = 2
        pool_range_end   = 254
      }
    }
    "RED" = {
      cidr = "10.0.30.1/24"
      pvid = 30
      dhcp = {
        enabled          = true
        pool_range_start = 2
        pool_range_end   = 254
      }
    }
  }
}
variable "lan_dhcp_clients_fw_addr_list_name" {
  description = "The name of the Firewall Address list that will contain VLANs all who require DHCP"
  type        = string
  default     = "AL_T_LAN_DHCP_CLIENTS"
}
variable "lan_internet_clients_fw_addr_list_name" {
  description = "The name of the Firewall Address list that will contain all VLANs who require Internet Access"
  type        = string
  default     = "AL_T_LAN_INTERNET"
}

# ------------------------------------------
# VLAN
# ------------------------------------------
variable "admin_user_credentials" {
  description = <<-EOT
    Admin username and respective SSH Key.
    This credentials are needed to install the required WLAN firmware (RouterOS package) for
    Wireless interfaces to be available, if package is not already present
  EOT
  type = object({
    name    = optional(string)
    ssh_key = optional(string)
  })
  sensitive = true
  default = {
    name = "alucard"
  }
}
variable "device_mgmt_ip" {
  description = <<-EOT
    The MGMT IP of the device currently working with.
    This IP is needed to install the required WLAN firmware (RouterOS package) for
    Wireless interfaces to be available, if package is not already present
  EOT
  type        = string
  default     = "192.168.88.1"
}
variable "default_wlan_interfaces" {
  description = <<-EOT
    The expected default names and frequencies of the WiFi interfaces in the device.
    This is used to determine whether an installation of the required package (firmware) is needed or not.
  EOT
  type        = list(string)
  default     = ["wlan1", "wlan2"]
}