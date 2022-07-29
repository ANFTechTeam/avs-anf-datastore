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

