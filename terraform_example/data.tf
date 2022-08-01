data "azurerm_resource_group" "avs_rg_1" {
    name = var.avs_rg_1_name
}

data "azurerm_resource_group" "avs_vnet_1_rg" {
    name = var.avs_vnet_1_rg_name
}

data "azurerm_virtual_network" "avs_vnet_1" {
    name = var.avs_vnet_1_name
    resource_group_name = data.azurerm_resource_group.avs_vnet_1_rg.name
}

data "azurerm_vmware_private_cloud" "avs_privatecloud_1" {
    name = var.avs_privatecloud_1_name
    resource_group_name = data.azurerm_resource_group.avs_rg_1.name
}

data "azurerm_netapp_volume" "anf_datastorevolume_1" {
    depends_on = [
        azapi_resource.avs_anf_volume_avsdatastoreenabled
    ]
    name = var.avs_anf_volume_1_name
    account_name = var.avs_anf_account_1_name
    pool_name = var.avs_anf_pool_1_name
    resource_group_name = data.azurerm_resource_group.avs_rg_1.name
}

