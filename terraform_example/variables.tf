variable "avs_rg_1_name" {
    description   = "Name of RG containing all AVS resources"
    default       = ""
}

variable "avs_rg_1_location" {
    description = "Location of RG containing all AVS resources"
    default     = ""
}

variable "avs_privatecloud_1_name" {
    description = "Name of the AVS private cloud we are attaching to"
    default     = ""
}

variable "avs_vnet_1_rg_name" {
    description = "Resource Group containing VNet"
}


variable "avs_vnet_1_name" {
    description = "Primary VNet Name"
    default     = ""
}

variable "avs_vnet_1_anfsubnet_name" {
    description = "ANF Subnet Name"
}

variable "avs_vnet_1_anfsubnet_address_space" {
    description = "ANF Subnet Address Space"
}

variable "avs_anf_account_1_name" {
    description = "ANF NetApp Account 1 Name"
}

variable "avs_anf_pool_1_name" {
    description = "ANF Pool 1 Name"
}

variable "avs_anf_pool_1_service_level" {
    description = "Pool Service Level"
}

variable "avs_anf_pool_1_size" {
    description = "Pool Size in TiB"
}

variable "avs_anf_volume_1_name" {
    description = "Volume 1 Name"
}

variable "avs_anf_volume_1_service_level" {
    description = "Volume 1 Service Level"
}

variable "avs_anf_volume_1_size" {
    description = "Volume 1 Size in GiB"
}

variable "avs_anf_volume_1_size_bytes" {
    description = "Volume 1 Size in Bytes"
} 
