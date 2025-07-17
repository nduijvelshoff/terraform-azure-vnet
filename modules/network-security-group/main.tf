# network security group
resource "azurerm_network_security_group" "nsg" {
  name = coalesce(
    lookup(var.network_security_group, "name", null),
    try("${var.naming.network_security_group}-${var.nsg_key}", null)
  )

  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  lifecycle {
    ignore_changes = [security_rule]
  }
}

# security rules
resource "azurerm_network_security_rule" "rules" {
  for_each = var.security_rules

  name                                       = each.value.rule_name
  priority                                   = each.value.rule.priority
  direction                                  = each.value.rule.direction
  access                                     = each.value.rule.access
  protocol                                   = each.value.rule.protocol
  source_port_range                          = each.value.rule.source_port_range
  source_port_ranges                         = each.value.rule.source_port_ranges
  destination_port_range                     = each.value.rule.destination_port_range
  destination_port_ranges                    = each.value.rule.destination_port_ranges
  source_address_prefix                      = each.value.rule.source_address_prefix
  source_address_prefixes                    = each.value.rule.source_address_prefixes
  destination_address_prefix                 = each.value.rule.destination_address_prefix
  destination_address_prefixes               = each.value.rule.destination_address_prefixes
  description                                = each.value.rule.description
  network_security_group_name                = azurerm_network_security_group.nsg.name
  source_application_security_group_ids      = each.value.rule.source_application_security_group_ids
  destination_application_security_group_ids = each.value.rule.destination_application_security_group_ids

  resource_group_name = var.resource_group_name
}

# nsg associations
resource "azurerm_subnet_network_security_group_association" "nsg_as" {
  for_each = var.nsg_associations

  subnet_id                 = each.value.subnet_id
  network_security_group_id = azurerm_network_security_group.nsg.id

  depends_on = [
    azurerm_network_security_rule.rules
  ]
}
