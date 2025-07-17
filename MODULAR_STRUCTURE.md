# Terraform Azure VNet - Modular Architecture Documentation

This Terraform module has been refactored into a modular architecture where each child module handles a single resource type, and the for_each iteration logic is centralized in the root module for better organization and maintainability.

## Module Architecture

The main module consists of VNet resources in the root module and several specialized child modules:

### Root Module (Virtual Network Management)
- **Purpose**: Manages Virtual Networks, DNS servers, and orchestrates child modules
- **Resources**: 
  - `azurerm_virtual_network` - Primary virtual network resource
  - `azurerm_virtual_network_dns_servers` - DNS server configuration
  - `data.azurerm_virtual_network` - Data source for existing VNets
- **Orchestration**: Contains for_each iteration logic for calling child modules
- **Complex Logic**: Handles merging of shared and subnet-specific configurations

### 1. Subnet Module (`modules/subnet/`) - Single Resource Management
- **Purpose**: Manages individual subnet configurations
- **Resources**: 
  - `azurerm_subnet` - Single subnet resource per module instance
- **Features**: 
  - Subnet delegations for Azure services
  - Service endpoint configurations
  - Address prefix management
- **Invocation**: Called with `for_each` iteration in root module
- **Pattern**: One module instance per subnet

### 2. Network Security Group Module (`modules/network-security-group/`) - Comprehensive NSG Management
- **Purpose**: Manages a single NSG with all its related resources
- **Resources**: 
  - `azurerm_network_security_group` - Primary NSG resource
  - `azurerm_network_security_rule` - Security rules (via for_each for rules belonging to this NSG)
  - `azurerm_subnet_network_security_group_association` - Subnet associations (via for_each)
- **Features**:
  - Complete NSG lifecycle management
  - Security rule creation and management
  - Subnet association handling
  - Rule priority and conflict management
- **Invocation**: Called with `for_each` iteration in root module
- **Pattern**: One module instance per NSG, handling all related resources

### 3. Route Table Module (`modules/route-table/`) - Comprehensive Routing Management
- **Purpose**: Manages a single route table with all its related resources
- **Resources**: 
  - `azurerm_route_table` - Primary route table resource
  - `azurerm_route` - Individual routes (via for_each for routes belonging to this route table)
  - `azurerm_subnet_route_table_association` - Subnet associations (via for_each)
- **Features**:
  - Complete route table lifecycle management
  - Custom route creation and management
  - Subnet association handling
  - BGP route propagation control
- **Invocation**: Called with `for_each` iteration in root module
- **Pattern**: One module instance per route table, handling all related resources

### 4. VNet Peering Module (`modules/vnet-peering/`) - Cross-VNet Connectivity
- **Purpose**: Manages bidirectional VNet peering between local and remote virtual networks
- **Resources**: 
  - `azurerm_virtual_network_peering` - Local-to-remote peering connection
  - `azurerm_virtual_network_peering` - Remote-to-local peering connection (using remote provider)
- **Features**: 
  - Bidirectional peering configuration
  - Cross-subscription peering support via remote provider
  - Configurable peering options (gateway transit, forwarded traffic, virtual network access)
  - Subnet-level peering restrictions
  - IPv6 peering support
  - Automatic trigger-based updates for address space changes
- **Invocation**: Direct module call (standalone usage, not via for_each in root module)
- **Pattern**: Standalone module for connecting existing VNets

## Benefits of Modular Architecture

1. **Simplified Child Modules**: Each module focuses on a single resource type with clear responsibilities
2. **Centralized Orchestration**: All for_each iteration logic is consolidated in the root module
3. **Enhanced Control**: Complex associations and rules are managed centrally with proper dependency handling
4. **Improved Testability**: Focused modules are easier to test in isolation with clear input/output contracts
5. **Clear Separation of Concerns**: Distinct separation between resource creation and resource orchestration
6. **Enhanced Maintainability**: Changes to iteration logic don't require updates to child modules

## Architectural Design Principles

### Root Module Responsibilities:
- **Core Infrastructure**: Management of VNet and DNS server resources
- **Orchestration Logic**: Implementation of for_each loops for calling child modules
- **Configuration Merging**: Complex logic for merging shared and subnet-specific configurations
- **Dependency Management**: Ensuring proper resource creation order through dependency chains

### Child Module Responsibilities:
- **Subnets**: Individual subnet creation with delegations and service endpoint configurations
- **Network Security Groups**: Complete NSG management including security rules and subnet associations
- **Route Tables**: Comprehensive route table management including custom routes and subnet associations
- **VNet Peering**: Bidirectional peering between virtual networks (standalone usage pattern)
- **Resource Configuration**: Clean, focused configuration handling with well-defined outputs

## Module Dependency Management

The modules implement a carefully designed dependency chain managed through `depends_on` declarations:

### Primary Dependencies:
- **Subnet modules** → VNet resources in the root module (require VNet to exist)
- **NSG modules** → Subnet modules (via root module orchestration)
- **Route Table modules** → Subnet modules (via root module orchestration)

### Internal Dependencies:
- **Security rules** → NSG modules (rules require NSG to exist)
- **NSG associations** → Both subnet and NSG modules (require both resources)
- **Route table associations** → Both subnet and route table modules (require both resources)

### Standalone Dependencies:
- **VNet Peering module** → Existing VNets (operates independently, requires VNet IDs as input)

This dependency structure ensures resources are created in the correct sequence while maintaining clear separation of concerns and enabling proper resource lifecycle management.
