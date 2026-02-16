# routeros_interfaces

Terraform/Tofu module which creates/configures (virtual/pysical) network interfaces on RouterOS devices.

## Features

This module aims to provide a layer of abstraction to modify/create:
* Ethernet Interfaces
* VLANs
** IP
** DHCP
** Interfaces lists for required/unrequired Internet access and DHCP for simpler Firewall rules
* Detects if the device doesn't have installed the required package for Wireless interfaces to work and installs it
* Configures WAN with it's corresponding method of internet access (if PPPoE, credentials must be injected)

## Usage

### Configure ether1 as WAN interface with DHCP from ISP

```hcl
module "routeros_interfaces" {
  source = "git@github.com:ceso/tofu_routeros_interfaces.git"

  configure_wan_internet = true
  ethernet_interfaces = {
    "ether1" = {
      comment = "WAN",
      is_wan  = true,
      wan = {
        connection_type     = "dhcp",
        interface_list_name = "WAN",
        isp_provider        = "telekom",
        use_peer_dns        = false
      }
    }
  }
}
```

### Create 3 VLANs with sfp1, ether2 & ether3 as trunk ports for every VLAN. Ether4 as an access port for one of them & ether5 to 8 disabled

```hcl
module "routeros_interfaces" {
  source = "git@github.com:ceso/tofu_routeros_interfaces.git"

  configure_vlans              = true
  create_vlan_bridge_interface = true
  vlans = {
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
  ethernet_interfaces = {
    "sfp1" = {
      comment = "Trunk Port SFP+"
      vlan = {
        role = "trunk_port"
        tagged = [
          "BLUE",
          "GREEN",
          "RED"
        ]
      }
    }
    "ether2" = {
      comment = "Trunk Port Ether2"
      vlan = {
        role = "trunk_port"
        tagged = [
          "BLUE",
          "GREEN",
          "RED"
        ]
      }
    }
    "ether3" = {
      comment = "Trunk Port Ether3"
      vlan = {
        role = "trunk_port"
        tagged = [
          "BLUE",
          "GREEN",
          "RED"
        ]
      }
    }
    "ether4" = {
      comment = "Access Port Ether4"
      vlan = {
        role = "access_port"
        untagged = [
          "RED"
        ]
        mtu = {
          mtu = 1500
        }
      }
    }
    "ether5" = { comment = "Disabled", disabled = true }
    "ether6" = { comment = "Disabled", disabled = true }
    "ether7" = { comment = "Disabled", disabled = true }
    "ether8" = { comment = "Disabled", disabled = true }
  }
}
```

### Use the module as a Terragrunt Unit

First, check the documentation by Terragrunt regarding this:
* https://terragrunt.gruntwork.io/docs/features/units/
* https://terragrunt.gruntwork.io/docs/features/stacks/
* https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example
* https://github.com/gruntwork-io/terragrunt-infrastructure-catalog-example

Now, to use the module as a Terragrunt Unit, a terragrunt.hcl with the following content could be created for example:

```hcl
# ------------------------------------------
# Unit: RouterOS Interfaces
# ------------------------------------------
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::git@github.com:ceso/tofu_routeros_interfaces.git?ref=main"
}

inputs = try(values, {})
```

## TODO

* Add better validations for 'ethernet_interfaces' variable. For example:
** If 'is_wan' is 'true', force as only connection_types 'dhcp' or 'pppoe'
** If 'connection_type' has not been set as 'pppoe', do not allow setting 'pppoe_settings'
** If 'connection_type' is set as 'dhcp' do not allow the usage of 'pppoe_settings'
** If 'is_wan' is set to 'true', do not let 'wan_settings' to be empty
** Find a way to fail if pppoe is set as connection_tupe for internet, but no credentials are given (validation instead of generic TF/Tofu error)
* Look for a way to provide an automatic creation of begin/end markers
* Better handling of routeros provider & tofu/terrraform version
* Tagging for each version of the module
* Tests
* Other things that I might have overlooked or don't remember :). If you use the module and find something, please open an issue or a PR

## References

To create this module I took inspiration from the following sources. Do not forget to check them out :)

* https://github.com/mirceanton/mikrotik-terraform/blob/main/modules/mikrotik-base
** This one specially. Some of the code I took it from him and adapted it. If you read: thanks a lot for sharing Mircea!
* https://github.com/Schwitzd/IaC-HomeRouter
* https://forum.mikrotik.com/t/using-routeros-to-vlan-your-network/126489/1
* https://www.youtube.com/watch?v=4Z32oOPqCqc
* https://www.youtube.com/watch?v=US2EU6cgHQU
* https://www.youtube.com/watch?v=YMwOrc0LDP8
* https://help.mikrotik.com/docs/spaces/ROS/pages/328151/First+Time+Configuration
* help.mikrotik.com/docs/spaces/ROS/pages/2031625/PPPoE
* Others I might be forgetting :/

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_routeros"></a> [routeros](#requirement\_routeros) | 1.99.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_routeros"></a> [routeros](#provider\_routeros) | 1.99.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.download_wifi_npk](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.install_wifi_npk](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.upload_wifi_npk](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [routeros_interface_bridge.vlan_bridge](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_bridge) | resource |
| [routeros_interface_bridge_port.vlan_bridge_port](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_bridge_port) | resource |
| [routeros_interface_bridge_vlan.vlan_bridge_vlan](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_bridge_vlan) | resource |
| [routeros_interface_detect_internet.detect_internet](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_detect_internet) | resource |
| [routeros_interface_ethernet.eth](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_ethernet) | resource |
| [routeros_interface_list.vlan_dhcp_client_list_interface](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_list) | resource |
| [routeros_interface_list.vlan_internet_access_list_interface](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_list) | resource |
| [routeros_interface_list.wan_list_interface](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_list) | resource |
| [routeros_interface_list_member.vlan_dhcp_list_member](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_list_member) | resource |
| [routeros_interface_list_member.vlan_internet_list_member](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_list_member) | resource |
| [routeros_interface_list_member.wan_list_member](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_list_member) | resource |
| [routeros_interface_pppoe_client.pppoe_client](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_pppoe_client) | resource |
| [routeros_interface_vlan.interface_vlan](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/interface_vlan) | resource |
| [routeros_ip_address.vlan_address](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/ip_address) | resource |
| [routeros_ip_dhcp_client.wan_dhcp_client](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/ip_dhcp_client) | resource |
| [routeros_ip_dhcp_server.vlan_dhcp_server](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/ip_dhcp_server) | resource |
| [routeros_ip_dhcp_server_network.vlan_dhcp_server_network](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/ip_dhcp_server_network) | resource |
| [routeros_ip_pool.vlan_pool_addr](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/resources/ip_pool) | resource |
| [routeros_interfaces.interfaces](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/data-sources/interfaces) | data source |
| [routeros_system_resource.routeros_system_resource](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/data-sources/system_resource) | data source |
| [routeros_system_routerboard.routeros_installed_firmware](https://registry.terraform.io/providers/terraform-routeros/routeros/1.99.0/docs/data-sources/system_routerboard) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_user_credentials"></a> [admin\_user\_credentials](#input\_admin\_user\_credentials) | Admin username and respective SSH Key.<br/>This credentials are needed to install the required WLAN firmware (RouterOS package) for<br/>Wireless interfaces to be available, if package is not already present | <pre>object({<br/>    name    = optional(string)<br/>    ssh_key = optional(string)<br/>  })</pre> | <pre>{<br/>  "name": "alucard"<br/>}</pre> | no |
| <a name="input_configure_vlans"></a> [configure\_vlans](#input\_configure\_vlans) | Whether to configure VLANs or not | `bool` | `false` | no |
| <a name="input_configure_wan_internet"></a> [configure\_wan\_internet](#input\_configure\_wan\_internet) | Whether to configure WAN (Internet) or not | `bool` | `false` | no |
| <a name="input_create_vlan_bridge_interface"></a> [create\_vlan\_bridge\_interface](#input\_create\_vlan\_bridge\_interface) | Whether to create a Brdige interface for VLANs or not | `bool` | `false` | no |
| <a name="input_default_wlan_interfaces"></a> [default\_wlan\_interfaces](#input\_default\_wlan\_interfaces) | The expected default names and frequencies of the WiFi interfaces in the device.<br/>This is used to determine whether an installation of the required package (firmware) is needed or not. | `list(string)` | <pre>[<br/>  "wlan1",<br/>  "wlan2"<br/>]</pre> | no |
| <a name="input_device_mgmt_ip"></a> [device\_mgmt\_ip](#input\_device\_mgmt\_ip) | The MGMT IP of the device currently working with.<br/>This IP is needed to install the required WLAN firmware (RouterOS package) for<br/>Wireless interfaces to be available, if package is not already present | `string` | `"192.168.88.1"` | no |
| <a name="input_device_mode"></a> [device\_mode](#input\_device\_mode) | Whether the device is being configured as a router or a switch | `string` | `"router"` | no |
| <a name="input_ethernet_interfaces"></a> [ethernet\_interfaces](#input\_ethernet\_interfaces) | A map containing all of the ethernet interfaces to be configured | <pre>map(object({<br/>    is_wan      = optional(bool, false)<br/>    bridge_port = optional(bool, true)<br/>    comment     = optional(string)<br/>    bandwidth   = optional(string)<br/>    disabled    = optional(bool)<br/>    # For more information on MTU, check the official documentation<br/>    # * https://help.mikrotik.com/docs/spaces/ROS/pages/21725296/MTU+in+RouterOS<br/>    mtu = optional(object({<br/>      mtu   = optional(number)<br/>      l2mtu = optional(number)<br/>    }))<br/>    # For more information on Link, auto mode, force mode, etc. check the official documentation<br/>    # * https://help.mikrotik.com/docs/spaces/ROS/pages/8323191/Ethernet#Ethernet-Auto-negotiationandForcedLinkMode<br/>    link = optional(object({<br/>      combo_mode       = optional(string)<br/>      fec_mode         = optional(string)<br/>      advertise        = optional(string)<br/>      speed            = optional(string)<br/>      auto_negotiation = optional(bool)<br/>      full_duplex      = optional(bool)<br/>      mdix_enable      = optional(bool)<br/>    }))<br/>    arp = optional(object({<br/>      mode        = optional(string)<br/>      timeout     = optional(string)<br/>      mac_address = optional(string)<br/>    }))<br/>    flow_control = optional(object({<br/>      rx = optional(string)<br/>      tx = optional(string)<br/>    }))<br/>    loop_protect = optional(object({<br/>      mode          = optional(string)<br/>      disable_time  = optional(string)<br/>      send_interval = optional(string)<br/>    }))<br/>    sfp = optional(object({<br/>      rate_select          = optional(string)<br/>      shutdown_temperature = optional(number)<br/>      ignore_rx_los        = optional(bool)<br/>    }))<br/>    poe = optional(object({<br/>      out          = optional(string)<br/>      voltage      = optional(string)<br/>      priority     = optional(number)<br/>      lldp_enabled = optional(bool)<br/>    }))<br/>    power_cycle = optional(object({<br/>      interval     = optional(string)<br/>      ping_address = optional(string)<br/>      ping_timeout = optional(string)<br/>      ping_enabled = optional(bool)<br/>    }))<br/>    advanced = optional(object({<br/>      cable_settings        = optional(string)<br/>      disable_running_check = optional(bool)<br/>    }))<br/>    vlan = optional(object({<br/>      role     = string<br/>      tagged   = optional(list(string))<br/>      untagged = optional(list(string))<br/>    }))<br/>    wan = optional(object({<br/>      connection_type     = optional(string, "dhcp")<br/>      use_peer_dns        = optional(bool, false)<br/>      interface_list_name = optional(string)<br/>      isp_provider        = optional(string)<br/>      pppoe_settings = optional(object({<br/>        # PPPoE settings to use when Internet Connection method is PPPoE.<br/>        # For details regarding some of these settings, please refer to MikroTik's official<br/>        # PPPoE documentation: https://help.mikrotik.com/docs/spaces/ROS/pages/2031625/PPPoE<br/>        max_mtu = optional(number, 1460)<br/>        max_mru = optional(number, 1460)<br/><br/>      }))<br/>    }))<br/>  }))</pre> | <pre>{<br/>  "ether1": {<br/>    "comment": "WAN",<br/>    "is_wan": true,<br/>    "wan": {<br/>      "connection_type": "pppoe"<br/>    }<br/>  },<br/>  "ether2": {<br/>    "comment": "Disabled",<br/>    "disabled": true<br/>  },<br/>  "ether3": {<br/>    "comment": "Disabled",<br/>    "disabled": true<br/>  },<br/>  "ether4": {<br/>    "comment": "Disabled",<br/>    "disabled": true<br/>  },<br/>  "ether5": {<br/>    "comment": "Disabled",<br/>    "disabled": true<br/>  },<br/>  "ether6": {<br/>    "comment": "Disabled",<br/>    "disabled": true<br/>  },<br/>  "ether7": {<br/>    "comment": "Disabled",<br/>    "disabled": true<br/>  },<br/>  "ether8": {<br/>    "comment": "RED_IOT Access",<br/>    "mtu": {<br/>      "mtu": 1500<br/>    },<br/>    "vlan": {<br/>      "role": "access_port",<br/>      "untagged": [<br/>        "RED_IOT"<br/>      ]<br/>    }<br/>  },<br/>  "sfp1": {<br/>    "comment": "Trunk Port SFP+",<br/>    "vlan": {<br/>      "role": "trunk_port",<br/>      "tagged": [<br/>        "BLUE_OFFICE",<br/>        "GREEN_TRUSTED"<br/>      ],<br/>      "untagged": [<br/>        "BLACKHOLE"<br/>      ]<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_lan_dhcp_clients_fw_addr_list_name"></a> [lan\_dhcp\_clients\_fw\_addr\_list\_name](#input\_lan\_dhcp\_clients\_fw\_addr\_list\_name) | The name of the Firewall Address list that will contain VLANs all who require DHCP | `string` | `"AL_T_LAN_DHCP_CLIENTS"` | no |
| <a name="input_lan_internet_clients_fw_addr_list_name"></a> [lan\_internet\_clients\_fw\_addr\_list\_name](#input\_lan\_internet\_clients\_fw\_addr\_list\_name) | The name of the Firewall Address list that will contain all VLANs who require Internet Access | `string` | `"AL_T_LAN_INTERNET"` | no |
| <a name="input_verify_wifi_interfaces_present_install"></a> [verify\_wifi\_interfaces\_present\_install](#input\_verify\_wifi\_interfaces\_present\_install) | Whether to verify if the firmware for Wireless interfaces to work is installed or not.<br/>Would it not be present, it will automatically install it | `bool` | `false` | no |
| <a name="input_vlan_bridge_name"></a> [vlan\_bridge\_name](#input\_vlan\_bridge\_name) | The name of the bridge interface VLANs use (with Hardware offloading) | `string` | `"BR_VLAN"` | no |
| <a name="input_vlans"></a> [vlans](#input\_vlans) | Map of VLANs to configure | <pre>map(object({<br/>    dns_server_ips  = optional(list(string))<br/>    internet_access = optional(bool, false)<br/>    cidr            = optional(string)<br/>    pvid            = number<br/>    dhcp = object({<br/>      enabled          = bool<br/>      pool_range_start = optional(number, 2)<br/>      pool_range_end   = optional(number, -2)<br/>    })<br/>  }))</pre> | <pre>{<br/>  "BLUE": {<br/>    "cidr": "10.0.10.1/24",<br/>    "dhcp": {<br/>      "enabled": true,<br/>      "pool_range_end": 254,<br/>      "pool_range_start": 2<br/>    },<br/>    "internet_access": true,<br/>    "pvid": 10<br/>  },<br/>  "GREEN": {<br/>    "cidr": "10.0.20.1/24",<br/>    "dhcp": {<br/>      "enabled": true,<br/>      "pool_range_end": 254,<br/>      "pool_range_start": 2<br/>    },<br/>    "internet_access": true,<br/>    "pvid": 20<br/>  },<br/>  "RED": {<br/>    "cidr": "10.0.30.1/24",<br/>    "dhcp": {<br/>      "enabled": true,<br/>      "pool_range_end": 254,<br/>      "pool_range_start": 2<br/>    },<br/>    "pvid": 30<br/>  }<br/>}</pre> | no |
| <a name="input_wan_pppoe_credentials"></a> [wan\_pppoe\_credentials](#input\_wan\_pppoe\_credentials) | PPPoE client credentials | <pre>object({<br/>    username = optional(string)<br/>    password = optional(string)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bridge_ports_vlan_rendered"></a> [bridge\_ports\_vlan\_rendered](#output\_bridge\_ports\_vlan\_rendered) | Brdige Ports/VLANs map rendered |
| <a name="output_interface_vlan_entries"></a> [interface\_vlan\_entries](#output\_interface\_vlan\_entries) | Per-Interface VLAN declarations |
| <a name="output_system_architecture"></a> [system\_architecture](#output\_system\_architecture) | Architecture of the current device |
| <a name="output_system_version"></a> [system\_version](#output\_system\_version) | Firmware version of the current device |
| <a name="output_vlans_rendered"></a> [vlans\_rendered](#output\_vlans\_rendered) | VLANs to be created |
<!-- END_TF_DOCS -->
