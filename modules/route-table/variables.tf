variable "route_table" {
  description = "Route table configuration"
  type = object({
    name                          = optional(string)
    bgp_route_propagation_enabled = optional(bool, true)
  })
}

variable "route_table_key" {
  description = "Key/name identifier for the route table"
  type        = string
}

variable "routes" {
  description = "Map of route configurations for this route table"
  type = map(object({
    route_name = string
    route = object({
      address_prefix         = string
      next_hop_type          = string
      next_hop_in_ip_address = optional(string)
    })
  }))
  default = {}
}

variable "route_table_associations" {
  description = "Map of route table association configurations for this route table"
  type = map(object({
    subnet_id = string
  }))
  default = {}
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "naming" {
  description = "Naming configuration for resources"
  type = object({
    route_table = optional(string, "rt")
  })
  default = {
    route_table = "rt"
  }
}
