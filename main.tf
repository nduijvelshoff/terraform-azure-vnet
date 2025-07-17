# existing virtual network
data "azurerm_virtual_network" "existing" {
  for_each = var.use_existing_vnet || try(
    var.vnet.use_existing_vnet, false
  ) ? { "vnet" = var.vnet } : {}

  name = each.value.name

  resource_group_name = coalesce(
    lookup(
      var.vnet, "resource_group_name", null
    ), var.resource_group_name
  )
}

# virtual network
resource "azurerm_virtual_network" "vnet" {
  for_each = var.use_existing_vnet || try(
    var.vnet.use_existing_vnet, false
  ) ? {} : { "vnet" = var.vnet }

  resource_group_name = coalesce(
    lookup(
      var.vnet, "resource_group_name", null
    ), var.resource_group_name
  )

  location = coalesce(
    lookup(var.vnet, "location", null
    ), var.location
  )

  name          = var.vnet.name
  address_space = var.vnet.address_space

  dynamic "ip_address_pool" {
    for_each = var.vnet.address_space == null && var.vnet.ip_address_pool != null ? [var.vnet.ip_address_pool] : []

    content {
      id                     = ip_address_pool.value.id
      number_of_ip_addresses = ip_address_pool.value.number_of_ip_addresses
    }
  }

  edge_zone                      = var.vnet.edge_zone
  bgp_community                  = var.vnet.bgp_community
  flow_timeout_in_minutes        = var.vnet.flow_timeout_in_minutes
  private_endpoint_vnet_policies = var.vnet.private_endpoint_vnet_policies

  dynamic "ddos_protection_plan" {
    for_each = try(var.vnet.ddos_protection_plan, null) != null ? [var.vnet.ddos_protection_plan] : []

    content {
      id     = ddos_protection_plan.value.id
      enable = ddos_protection_plan.value.enable
    }
  }

  dynamic "encryption" {
    for_each = try(var.vnet.encryption, null) != null ? [var.vnet.encryption] : []

    content {
      enforcement = encryption.value.enforcement
    }
  }

  tags = coalesce(
    var.vnet.tags, var.tags
  )

  lifecycle {
    ignore_changes = [subnet, dns_servers]
  }
}

# dns servers
resource "azurerm_virtual_network_dns_servers" "dns" {
  for_each = {
    for k, v in {
      "default" = try(
        var.vnet.dns_servers, []
      )
    } : k => v
    if length(v) > 0
  }

  virtual_network_id = (var.use_existing_vnet ||
    try(
      var.vnet.use_existing_vnet, false
    )
  ) ? data.azurerm_virtual_network.existing["vnet"].id : azurerm_virtual_network.vnet["vnet"].id

  dns_servers = each.value
}

# Subnets Module - for_each to create multiple subnets
module "subnets" {
  source   = "./modules/subnet"
  for_each = try(var.vnet.subnets, {})

  subnet               = each.value
  subnet_key           = each.key
  resource_group_name  = coalesce(lookup(var.vnet, "resource_group_name", null), var.resource_group_name)
  virtual_network_name = (var.use_existing_vnet || try(var.vnet.use_existing_vnet, false)) ? data.azurerm_virtual_network.existing["vnet"].name : azurerm_virtual_network.vnet["vnet"].name
  naming               = var.naming
}

# Local variables for processing NSGs and rules
locals {
  # Merge shared NSGs with subnet-specific NSGs
  network_security_groups = merge(
    # Handle top-level shared NSGs
    try(var.vnet.network_security_groups, {}),
    # Handle subnet NSGs
    {
      for subnet_key, subnet in try(var.vnet.subnets, {}) : subnet_key => lookup(subnet, "network_security_group", null)
      if lookup(subnet, "network_security_group", null) != null
    }
  )

  # Process security rules from both shared and subnet NSGs - grouped by NSG
  rules_by_nsg = {
    for nsg_key in keys(local.network_security_groups) : nsg_key => merge(
      # Rules from shared NSGs
      contains(keys(try(var.vnet.network_security_groups, {})), nsg_key) ? {
        for rule_key, rule in lookup(try(var.vnet.network_security_groups[nsg_key], {}), "rules", {}) : rule_key => {
          rule_name = coalesce(
            rule.name, try(join("-", [var.naming.network_security_group_rule, rule_key]), rule_key)
          )
          rule = rule
        }
      } : {},
      # Rules from subnet NSGs
      contains(keys(try(var.vnet.subnets, {})), nsg_key) ? {
        for rule_key, rule in lookup(lookup(try(var.vnet.subnets[nsg_key], {}), "network_security_group", {}), "rules", {}) : rule_key => {
          rule_name = coalesce(
            rule.name, try(join("-", [var.naming.network_security_group_rule, rule_key]), rule_key)
          )
          rule = rule
        }
      } : {}
    )
  }

  # NSG associations - grouped by NSG
  associations_by_nsg = {
    for nsg_key in keys(local.network_security_groups) : nsg_key => {
      for subnet_key, subnet in try(var.vnet.subnets, {}) : subnet_key => {
        subnet_id = module.subnets[subnet_key].subnet.id
      }
      if(lookup(subnet, "network_security_group", null) != null && nsg_key == subnet_key) ||
      (lookup(lookup(subnet, "shared", {}), "network_security_group", null) != null && nsg_key == lookup(lookup(subnet, "shared", {}), "network_security_group"))
    }
  }
}

# Network Security Groups Module - for_each to create multiple NSGs
module "network_security_groups" {
  source   = "./modules/network-security-group"
  for_each = local.network_security_groups

  network_security_group = each.value
  nsg_key                = each.key
  security_rules         = local.rules_by_nsg[each.key]
  nsg_associations       = local.associations_by_nsg[each.key]
  resource_group_name    = coalesce(lookup(var.vnet, "resource_group_name", null), var.resource_group_name)
  location               = coalesce(lookup(var.vnet, "location", null), var.location)
  tags                   = coalesce(var.vnet.tags, var.tags)
  naming                 = var.naming

  depends_on = [module.subnets]
}

# Local variables for processing route tables
locals {
  # Merge shared route tables with subnet-specific route tables
  route_tables = merge(
    try(var.vnet.route_tables, {}),
    # subnet level route tables
    {
      for subnet_key, subnet in try(var.vnet.subnets, {}) :
      subnet_key => subnet.route_table
      if lookup(subnet, "route_table", null) != null
    }
  )

  # Process routes from both shared and subnet route tables - grouped by route table
  routes_by_rt = {
    for rt_key in keys(local.route_tables) : rt_key => merge(
      # Routes from shared route tables
      contains(keys(try(var.vnet.route_tables, {})), rt_key) ? {
        for route_key, route in lookup(try(var.vnet.route_tables[rt_key], {}), "routes", {}) : route_key => {
          route_name = coalesce(
            route.name, join("-", [try(var.naming.route, "rt"), route_key])
          )
          route = route
        }
      } : {},
      # Routes from subnet route tables  
      contains(keys(try(var.vnet.subnets, {})), rt_key) ? {
        for route_key, route in lookup(lookup(try(var.vnet.subnets[rt_key], {}), "route_table", {}), "routes", {}) : route_key => {
          route_name = coalesce(
            route.name, join("-", [try(var.naming.route, "rt"), route_key])
          )
          route = route
        }
      } : {}
    )
  }

  # Route table associations - grouped by route table
  associations_by_rt = {
    for rt_key in keys(local.route_tables) : rt_key => {
      for k, v in try(var.vnet.subnets, {}) : k => {
        subnet_id = module.subnets[k].subnet.id
      }
      if(lookup(v, "route_table", null) != null && rt_key == k) ||
      (lookup(lookup(v, "shared", {}), "route_table", null) != null && rt_key == lookup(lookup(v, "shared", {}), "route_table"))
    }
  }
}

# Route Tables Module - for_each to create multiple route tables
module "route_tables" {
  source   = "./modules/route-table"
  for_each = local.route_tables

  route_table              = each.value
  route_table_key          = each.key
  routes                   = local.routes_by_rt[each.key]
  route_table_associations = local.associations_by_rt[each.key]
  resource_group_name      = coalesce(lookup(var.vnet, "resource_group_name", null), var.resource_group_name)
  location                 = coalesce(lookup(var.vnet, "location", null), var.location)
  tags                     = coalesce(var.vnet.tags, var.tags)
  naming                   = var.naming

  depends_on = [module.subnets]
}
