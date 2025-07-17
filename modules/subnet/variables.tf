variable "subnet" {
  description = "Subnet configuration"
  type = object({
    name                                          = optional(string)
    address_prefixes                              = list(string)
    service_endpoints                             = optional(list(string), [])
    private_link_service_network_policies_enabled = optional(bool, false)
    private_endpoint_network_policies             = optional(string, "Disabled")
    service_endpoint_policy_ids                   = optional(list(string), [])
    default_outbound_access_enabled               = optional(bool, null)
    delegations = optional(map(object({
      name    = string
      actions = optional(list(string), [])
    })), {})
  })
}

variable "subnet_key" {
  description = "Key/name identifier for the subnet"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "naming" {
  description = "Naming configuration for resources"
  type = object({
    subnet = optional(string, "snet")
  })
  default = {
    subnet = "snet"
  }
}
