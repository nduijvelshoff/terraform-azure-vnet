# Terraform State Update Guide - Modular Migration

This guide helps you migrate from the monolithic terraform-azure-vnet module to the new modular structure without destroying and recreating your existing resources.

## Overview of Changes

The module has been refactored from a monolithic structure to a modular one:

### Before (Monolithic)
- All resources in single module
- Direct resource creation in main.tf
- Single outputs file

### After (Modular)
- VNet resources remain in root module
- Subnets managed by `modules/subnet`
- NSGs managed by `modules/network-security-group`
- Route tables managed by `modules/route-table`
- Each module uses `for_each` for multiple instances

## Breaking Changes

1. **Resource Addresses Changed**: Resources moved to module addresses
2. **State Structure**: Resources now under module paths
3. **Output Structure**: Outputs now reference module outputs

## Migration Steps

### Step 1: Backup Current State

```bash
# Create backup of current state
terraform state pull > terraform.tfstate.backup

# List current resources
terraform state list > current_resources.txt
```

### Step 2: Update Module Source

Update your module call to use the new version:

```hcl
module "vnet" {
  source = "./path/to/new/modular/terraform-azure-vnet"
  
  # Your existing configuration remains the same
  vnet = {
    # ... existing config
  }
}
```

### Step 3: Plan and Identify Resources to Move

```bash
# Run terraform plan to see what will be destroyed/created
terraform plan -out=migration.tfplan

# Review the plan carefully - you should see:
# - Resources being destroyed (old addresses)
# - Resources being created (new module addresses)
```

### Step 4: Move Resources in State

Use `terraform state mv` to move resources to their new module addresses.

#### A. Move Subnets

For each subnet, move from old to new address:

```bash
# Pattern: subnet resources
terraform state mv 'module.vnet.azurerm_subnet.subnet["subnet_name"]' 'module.vnet.module.subnets["subnet_name"].azurerm_subnet.subnet'

# Example for subnet named "web":
terraform state mv 'module.vnet.azurerm_subnet.subnet["web"]' 'module.vnet.module.subnets["web"].azurerm_subnet.subnet'
```

#### B. Move Network Security Groups

```bash
# Pattern: NSG resources
terraform state mv 'module.vnet.azurerm_network_security_group.nsg["nsg_name"]' 'module.vnet.module.network_security_groups["nsg_name"].azurerm_network_security_group.nsg'

# Pattern: NSG rules
terraform state mv 'module.vnet.azurerm_network_security_rule.nsg_rules["nsg_name-rule_name"]' 'module.vnet.module.network_security_groups["nsg_name"].azurerm_network_security_rule.rules["rule_name"]'

# Pattern: NSG associations
terraform state mv 'module.vnet.azurerm_subnet_network_security_group_association.nsg_as["subnet_name"]' 'module.vnet.module.network_security_groups["nsg_name"].azurerm_subnet_network_security_group_association.nsg_as["subnet_name"]'

# Examples:
terraform state mv 'module.vnet.azurerm_network_security_group.nsg["web"]' 'module.vnet.module.network_security_groups["web"].azurerm_network_security_group.nsg'
terraform state mv 'module.vnet.azurerm_network_security_rule.nsg_rules["web-allow_http"]' 'module.vnet.module.network_security_groups["web"].azurerm_network_security_rule.rules["allow_http"]'
```

#### C. Move Route Tables

```bash
# Pattern: Route table resources
terraform state mv 'module.vnet.azurerm_route_table.rt["rt_name"]' 'module.vnet.module.route_tables["rt_name"].azurerm_route_table.rt'

# Pattern: Routes
terraform state mv 'module.vnet.azurerm_route.rt_routes["rt_name-route_name"]' 'module.vnet.module.route_tables["rt_name"].azurerm_route.routes["route_name"]'

# Pattern: Route table associations
terraform state mv 'module.vnet.azurerm_subnet_route_table_association.rt_as["subnet_name"]' 'module.vnet.module.route_tables["rt_name"].azurerm_subnet_route_table_association.rt_as["subnet_name"]'

# Examples:
terraform state mv 'module.vnet.azurerm_route_table.rt["main"]' 'module.vnet.module.route_tables["main"].azurerm_route_table.rt'
terraform state mv 'module.vnet.azurerm_route.rt_routes["main-to_firewall"]' 'module.vnet.module.route_tables["main"].azurerm_route.routes["to_firewall"]'
```

### Step 5: Helper Script for Bulk Operations

Create a script to automate the moves:

```bash
#!/bin/bash
# migrate_state.sh

echo "Starting Terraform state migration..."

# Get list of current resources
terraform state list > current_resources.txt

# Move subnets
echo "Moving subnets..."
grep 'azurerm_subnet.subnet\[' current_resources.txt | while read -r resource; do
    subnet_key=$(echo "$resource" | sed -n 's/.*subnet\["\([^"]*\)"\].*/\1/p')
    if [ ! -z "$subnet_key" ]; then
        echo "Moving subnet: $subnet_key"
        terraform state mv "$resource" "module.vnet.module.subnets[\"$subnet_key\"].azurerm_subnet.subnet"
    fi
done

# Move NSGs
echo "Moving NSGs..."
grep 'azurerm_network_security_group.nsg\[' current_resources.txt | while read -r resource; do
    nsg_key=$(echo "$resource" | sed -n 's/.*nsg\["\([^"]*\)"\].*/\1/p')
    if [ ! -z "$nsg_key" ]; then
        echo "Moving NSG: $nsg_key"
        terraform state mv "$resource" "module.vnet.module.network_security_groups[\"$nsg_key\"].azurerm_network_security_group.nsg"
    fi
done

# Move NSG rules
echo "Moving NSG rules..."
grep 'azurerm_network_security_rule.nsg_rules\[' current_resources.txt | while read -r resource; do
    # Extract nsg_key and rule_key from format: nsg_key-rule_key
    full_key=$(echo "$resource" | sed -n 's/.*nsg_rules\["\([^"]*\)"\].*/\1/p')
    nsg_key=$(echo "$full_key" | cut -d'-' -f1)
    rule_key=$(echo "$full_key" | cut -d'-' -f2-)
    if [ ! -z "$nsg_key" ] && [ ! -z "$rule_key" ]; then
        echo "Moving NSG rule: $nsg_key -> $rule_key"
        terraform state mv "$resource" "module.vnet.module.network_security_groups[\"$nsg_key\"].azurerm_network_security_rule.rules[\"$rule_key\"]"
    fi
done

# Move route tables
echo "Moving route tables..."
grep 'azurerm_route_table.rt\[' current_resources.txt | while read -r resource; do
    rt_key=$(echo "$resource" | sed -n 's/.*rt\["\([^"]*\)"\].*/\1/p')
    if [ ! -z "$rt_key" ]; then
        echo "Moving route table: $rt_key"
        terraform state mv "$resource" "module.vnet.module.route_tables[\"$rt_key\"].azurerm_route_table.rt"
    fi
done

# Move routes
echo "Moving routes..."
grep 'azurerm_route.rt_routes\[' current_resources.txt | while read -r resource; do
    # Extract rt_key and route_key from format: rt_key-route_key
    full_key=$(echo "$resource" | sed -n 's/.*rt_routes\["\([^"]*\)"\].*/\1/p')
    rt_key=$(echo "$full_key" | cut -d'-' -f1)
    route_key=$(echo "$full_key" | cut -d'-' -f2-)
    if [ ! -z "$rt_key" ] && [ ! -z "$route_key" ]; then
        echo "Moving route: $rt_key -> $route_key"
        terraform state mv "$resource" "module.vnet.module.route_tables[\"$rt_key\"].azurerm_route.routes[\"$route_key\"]"
    fi
done

echo "Migration complete!"
```

### Step 6: Verify Migration

```bash
# Make script executable and run
chmod +x migrate_state.sh
./migrate_state.sh

# Verify no changes needed
terraform plan

# Should show "No changes. Your infrastructure matches the configuration."
```

### Step 7: Update Output References

If you reference module outputs, update them:

#### Before:
```hcl
output "subnet_ids" {
  value = module.vnet.subnet_ids
}
```

#### After:
```hcl
output "subnet_ids" {
  value = module.vnet.subnets
}
```

## Common Issues and Solutions

### Issue 1: Resource Not Found
**Error**: `Resource not found in state`

**Solution**: Check the exact resource name with `terraform state list` and use the exact address.

### Issue 2: Duplicate Resources
**Error**: `Resource already exists in state`

**Solution**: Remove the duplicate first:
```bash
terraform state rm 'duplicate.resource.address'
```

### Issue 3: Association Dependencies
**Error**: Associations failing due to missing parent resources

**Solution**: Move parent resources first (NSGs before NSG associations, route tables before route associations).

### Issue 4: Wrong Module Reference
**Error**: Resources still being destroyed/created

**Solution**: Double-check the new module structure and ensure all moves completed successfully.

## Validation Checklist

- [ ] All subnets moved to `module.subnets["key"]`
- [ ] All NSGs moved to `module.network_security_groups["key"]`
- [ ] All NSG rules moved to correct NSG module
- [ ] All NSG associations moved to correct NSG module
- [ ] All route tables moved to `module.route_tables["key"]`
- [ ] All routes moved to correct route table module
- [ ] All route table associations moved to correct route table module
- [ ] `terraform plan` shows no changes
- [ ] All outputs still work correctly

## Rollback Plan

If something goes wrong:

```bash
# Restore from backup
terraform state push terraform.tfstate.backup

# Or restore specific resources
terraform import [resource_type].[resource_name] [azure_resource_id]
```

## Notes

1. **VNet Resources**: VNet and DNS server resources remain in the root module (no state moves needed)
2. **Resource Names**: Resource names within Azure remain unchanged
3. **Dependencies**: The new structure maintains all dependencies automatically
4. **Naming**: The module uses the same naming conventions as before

## Support

If you encounter issues during migration:

1. Check the exact resource addresses with `terraform state list`
2. Verify your configuration matches the new module structure
3. Use `terraform show` to inspect current state
4. Consider migrating one resource type at a time
