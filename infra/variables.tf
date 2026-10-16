variable "resource_group_name" {
  description = "Resource group name for workload resources."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
}

variable "workload_name" {
  description = "Workload prefix for resource names. Use lowercase letters, numbers, and hyphens."
  type        = string
  default     = "azureapi"
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management."
  type        = string
}

variable "apim_publisher_name" {
  description = "Publisher name for API Management."
  type        = string
  default     = "Contoso"
}

variable "vnet_address_prefix" {
  description = "Address space for workload virtual network."
  type        = string
  default     = "10.40.0.0/16"
}

variable "apim_subnet_prefix" {
  description = "Subnet for API Management internal mode. APIM requires /26 or larger."
  type        = string
  default     = "10.40.1.0/26"
}

variable "private_endpoint_subnet_prefix" {
  description = "Subnet for private endpoints."
  type        = string
  default     = "10.40.2.0/24"
}

variable "function_integration_subnet_prefix" {
  description = "Subnet for Function App regional VNet integration."
  type        = string
  default     = "10.40.3.0/24"
}

variable "apim_sku_name" {
  description = "API Management SKU (Developer or Premium)."
  type        = string
  default     = "Developer"

  validation {
    condition     = contains(["Developer", "Premium"], var.apim_sku_name)
    error_message = "apim_sku_name must be Developer or Premium."
  }
}

variable "apim_sku_capacity" {
  description = "API Management capacity units."
  type        = number
  default     = 1
}
