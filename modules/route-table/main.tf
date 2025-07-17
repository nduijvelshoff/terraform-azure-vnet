# route table
resource "azurerm_route_table" "rt" {
  name = coalesce(
    var.route_table.name, try(
      join("-", [var.naming.route_table, var.route_table_key]), null
    ), var.route_table_key
  )

  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  bgp_route_propagation_enabled = try(var.route_table.bgp_route_propagation_enabled, true)

  lifecycle {
    ignore_changes = [route]
  }
}

# routes
resource "azurerm_route" "routes" {
  for_each = var.routes

  name                   = each.value.route_name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = each.value.route.address_prefix
  next_hop_type          = each.value.route.next_hop_type
  next_hop_in_ip_address = each.value.route.next_hop_in_ip_address

  resource_group_name = var.resource_group_name
}

# route table associations
resource "azurerm_subnet_route_table_association" "rt_as" {
  for_each = var.route_table_associations

  subnet_id      = each.value.subnet_id
  route_table_id = azurerm_route_table.rt.id

  depends_on = [azurerm_route_table.rt]
}
