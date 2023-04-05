
variable "hdfc_resource_group_name" {
  description = "name of the resource group"
  type        = string
  default     = "prod-hdfc-europe"
}

variable "location_resource_group" {
  description = "location of the resource group"
  type        = string
  default     = "west europe"
}

variable "storage1" {
  description = "name of the storage"
  type        = string
  default     = "demo1storageacc"
}

variable "location" {
  description = "storage location"
  type        = string
  default     = "westus"
}

variable "access_tier" {
  description = "defines the storage account access tier "
  type        = string
  default     = "Hot"
}

variable "account_tier" {
  description = "defines the storage account account tier "
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "defines the storage account repliation type "
  type        = string
  default     = "GRS"
}


variable "account_kind" {
  description = "defines the storage account kind "
  type        = string
  default     = "BlobStorage"
}
