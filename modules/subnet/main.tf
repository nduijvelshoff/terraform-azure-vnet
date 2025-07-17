# subnet
resource "azurerm_subnet" "subnet" {
  name = coalesce(
    var.subnet.name, try(
      join("-", [var.naming.subnet, var.subnet_key]), null
    ), var.subnet_key
  )

  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name

  address_prefixes                              = var.subnet.address_prefixes
  service_endpoints                             = var.subnet.service_endpoints
  private_link_service_network_policies_enabled = var.subnet.private_link_service_network_policies_enabled
  private_endpoint_network_policies             = var.subnet.private_endpoint_network_policies
  service_endpoint_policy_ids                   = var.subnet.service_endpoint_policy_ids
  default_outbound_access_enabled               = var.subnet.default_outbound_access_enabled

  dynamic "delegation" {
    for_each = lookup(
      var.subnet, "delegations", {}
    )

    content {
      name = delegation.key

      service_delegation {
        name    = delegation.value.name
        actions = delegation.value.actions
      }
    }
  }
}
