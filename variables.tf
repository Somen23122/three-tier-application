# resource group name
variable "resource_group_name" {
  type        = string
  description = "Resource Group name"
}

# region
variable "location" {
  type        = string
  description = "Region"
}

variable "vm_size" {
  type        = string
  description = "vm size"
}