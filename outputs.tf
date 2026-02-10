# ------------------------------------------
# Device Information
# ------------------------------------------
output "system_architecture" {
  description = "Architecture of the current device"
  value       = local.system_architecture
}
output "system_version" {
  description = "Firmware version of the current device"
  value       = local.system_version
}

# ------------------------------------------
# VLANs
# ------------------------------------------
output "vlans_rendered" {
  description = "VLANs to be created"
  value       = try(local.vlans_rendered, null)
}
output "bridge_ports_vlan_rendered" {
  description = "Brdige Ports/VLANs map rendered"
  value       = try(local.bridge_ports_vlan_rendered, null)
}
output "interface_vlan_entries" {
  description = "Per-Interface VLAN declarations"
  value       = try(local.interface_vlan_entries, null)
}