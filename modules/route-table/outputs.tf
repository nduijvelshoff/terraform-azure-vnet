output "route_table" {
  description = "Contains route table configuration"
  value       = azurerm_route_table.rt
}

output "routes" {
  description = "Contains routes configuration"
  value       = azurerm_route.routes
}

output "route_table_associations" {
  description = "Contains route table association configuration"
  value       = azurerm_subnet_route_table_association.rt_as
}
