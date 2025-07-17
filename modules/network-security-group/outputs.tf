output "network_security_group" {
  description = "Contains network security group configuration"
  value       = azurerm_network_security_group.nsg
}

output "security_rules" {
  description = "Contains security rules configuration"
  value       = azurerm_network_security_rule.rules
}

output "nsg_associations" {
  description = "Contains NSG association configuration"
  value       = azurerm_subnet_network_security_group_association.nsg_as
}
