resource "azurerm_subnet" "avs_vnet_1_anfsubnet" {
    name                    = var.avs_vnet_1_anfsubnet_name
    resource_group_name     = data.azurerm_resource_group.avs_vnet_1_rg.name
    virtual_network_name    = data.azurerm_virtual_network.avs_vnet_1.name
    address_prefixes           = [var.avs_vnet_1_anfsubnet_address_space]

    delegation {
        name = "anf_delegation"
        service_delegation {
            name = "Microsoft.Netapp/volumes"
        }
    }
}

resource "azurerm_netapp_account" "avs_anf_account_1" {
    name                = var.avs_anf_account_1_name
    location            = var.avs_rg_1_location
    resource_group_name = data.azurerm_resource_group.avs_rg_1.name
}

resource "azurerm_netapp_pool" "avs_anf_pool_1" {
    name                = var.avs_anf_pool_1_name
    location            = var.avs_rg_1_location
    resource_group_name = data.azurerm_resource_group.avs_rg_1.name
    account_name        = azurerm_netapp_account.avs_anf_account_1.name
    service_level       = var.avs_anf_pool_1_service_level
    size_in_tb          = var.avs_anf_pool_1_size
}

/* place holder for when terraform updates with avsdatastore flag
resource "azurerm_netapp_volume" "avs_anf_volume_1" {
    lifecycle {
        prevent_destroy = false
    }

    name                       = var.avs_anf_volume_1_name
    location                   = azurerm_netapp_pool.avs_anf_pool_1.location
    resource_group_name        = data.azurerm_resource_group.avs_rg_1.name
    account_name               = azurerm_netapp_account.avs_anf_account_1.name
    pool_name                  = azurerm_netapp_pool.avs_anf_pool_1.name
    volume_path                = var.avs_anf_volume_1_name
    service_level              = var.avs_anf_volume_1_service_level
    subnet_id                  = azurerm_subnet.avs_vnet_1_anfsubnet.id
    protocols                  = ["NFSv3"]
    security_style             = "Unix"
    storage_quota_in_gb        = var.avs_anf_volume_1_size
    snapshot_directory_visible = true
    avsdatastore_enabled       = true #?!?! maybe?

    export_policy_rule {
        rule_index = 1
        allowed_clients = ["0.0.0.0/0"]
        protocols_enabled = ["NFSv3"]
        root_access_enabled = true
    }
}
*/

resource "azapi_resource" "avs_anf_volume_avsdatastoreenabled" {
    depends_on = [
        azurerm_netapp_pool.avs_anf_pool_1
    ]
    type = "Microsoft.NetApp/netAppAccounts/capacityPools/volumes@2022-01-01"
    name = var.avs_anf_volume_1_name
    parent_id = azurerm_netapp_pool.avs_anf_pool_1.id
    body = jsonencode({
        location = azurerm_netapp_pool.avs_anf_pool_1.location
        properties = {
            creationToken = var.avs_anf_volume_1_name,
            serviceLevel = var.avs_anf_volume_1_service_level,
            subnetId = azurerm_subnet.avs_vnet_1_anfsubnet.id,
            usageThreshold = var.avs_anf_volume_1_size_bytes,
            protocolTypes = ["NFSv3"],
            avsDataStore = "Enabled"
            exportPolicy = {
                rules = [
                    {
                        ruleIndex = 1,
                        allowedClients = "0.0.0.0/0",
                        unixReadOnly = false,
                        hasRootAccess = true,
                        nfsv3 = true
                    }
                ]
            }
        }
    })
}

resource "azapi_resource" "avs_datastore_attach_anfvolume" {
    type = "Microsoft.AVS/privateClouds/clusters/datastores@2021-12-01"
    name = var.avs_anf_volume_1_name
    parent_id = "${data.azurerm_vmware_private_cloud.avs_privatecloud_1.id}/clusters/Cluster-1"
    body = jsonencode({
        properties = {
            netAppVolume = {
                id = data.azurerm_netapp_volume.anf_datastorevolume_1.id
            }
        }
    })
}