output "vnet" {
  description = "contains virtual network configuration"
  value       = (var.use_existing_vnet || try(var.vnet.use_existing_vnet, false)) ? data.azurerm_virtual_network.existing["vnet"] : azurerm_virtual_network.vnet["vnet"]
}

output "subnets" {
  description = "contains subnet configuration"
  value       = { for k, v in module.subnets : k => v.subnet }
}

output "network_security_group" {
  description = "contains network security group configuration"
  value       = { for k, v in module.network_security_groups : k => v.network_security_group }
}

output "security_rules" {
  description = "contains security rules configuration"
  value       = { for k, v in module.network_security_groups : k => v.security_rules }
}

output "nsg_associations" {
  description = "contains NSG association configuration"
  value       = { for k, v in module.network_security_groups : k => v.nsg_associations }
}

output "route_tables" {
  description = "contains route table configuration"
  value       = { for k, v in module.route_tables : k => v.route_table }
}

output "routes" {
  description = "contains routes configuration"
  value       = { for k, v in module.route_tables : k => v.routes }
}

output "route_table_associations" {
  description = "contains route table association configuration"
  value       = { for k, v in module.route_tables : k => v.route_table_associations }
}
