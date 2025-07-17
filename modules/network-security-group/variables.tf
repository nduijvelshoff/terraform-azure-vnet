variable "network_security_group" {
  description = "Network security group configuration"
  type = object({
    name = optional(string)
  })
}

variable "nsg_key" {
  description = "Key/name identifier for the NSG"
  type        = string
}

variable "security_rules" {
  description = "Map of security rule configurations for this NSG"
  type = map(object({
    rule_name = string
    rule = object({
      priority                                   = number
      direction                                  = string
      access                                     = string
      protocol                                   = string
      source_port_range                          = optional(string)
      source_port_ranges                         = optional(list(string))
      destination_port_range                     = optional(string)
      destination_port_ranges                    = optional(list(string))
      source_address_prefix                      = optional(string)
      source_address_prefixes                    = optional(list(string))
      destination_address_prefix                 = optional(string)
      destination_address_prefixes               = optional(list(string))
      description                                = optional(string)
      source_application_security_group_ids      = optional(list(string))
      destination_application_security_group_ids = optional(list(string))
    })
  }))
  default = {}
}

variable "nsg_associations" {
  description = "Map of NSG association configurations for this NSG"
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
    network_security_group = optional(string, "nsg")
  })
  default = {
    network_security_group = "nsg"
  }
}
