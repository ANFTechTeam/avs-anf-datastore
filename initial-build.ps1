param (
    [string]$action
)

# set environment variables
$privateCloudResourceGroup = "AVS-VMwareExplore-HOL-PC01"
$privateClouds = ["AVS-VMwareExplore-HOL-PC01"]
$anfVnet = "avs-hol-vnet" #this vnet must be peered to the AVS vnet
$anfVnetResourceGroup = "AVS-VMwareExplore-HOL-RG" #this must be an existing resource group
$anfSubnet = "anf-subnet"
$anfSubnetPrefix = "10.0.14.64/26"
$anfResourceGroup = "AVS-VMwareExplore-HOL-RG" #this must be an existing resource group
$anfLocation = "westeurope"
$anfAccount = "AVS-VMwareExplore-HOL-ANFNA-A"
$anfPool = "AVS-VMwareExplore-HOL-ANFPool-A"
$anfPoolSize = 4 #tebibytes
$anfPoolServiceLevel = "Premium"
$anfVolume = "avsDatastore001"
$anfVolumeSize = 1 #tebibytes
$subId = (Get-AzContext).Subscription.Id

if(!($action)){
    write-host "no action specified, please use the '-action' flag with one of the following: 'build', 'cleanup', 'list'."
}


if($action -eq "build"){
    # Install Az.NetAppFiles PowerShell module
    write-host "Installing Az.NetAppFiles PowerShell Module..."
    Install-Module -Name Az.NetAppFiles -Scope CurrentUser -Repository PSGallery

    # Register Azure NetApp Files standard networking features
    write-host "Registering feature Microsoft.NetApp / ANFSDNAppliance..."
    Register-AzProviderFeature -ProviderNamespace Microsoft.NetApp -FeatureName ANFSDNAppliance
    write-host "Registering feature Microsoft.Network / AllowPoliciesOnBareMetal..."
    Register-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowPoliciesOnBareMetal

    # Register Azure NetApp Files datastore features
    write-host "Registering feature Microsoft.NetApp / ANFAvsDatastore..."
    Register-AzProviderFeature -FeatureName "ANFAvsDatastore" -ProviderNamespace "Microsoft.NetApp"
    write-host "Registering feature Microsoft.AVS / CloudSanExperience..."
    Register-AzProviderFeature -FeatureName "CloudSanExperience" -ProviderNamespace "Microsoft.AVS"
    write-host "Registering feature Microsoft.AVS / anfDatastoreExperience..."
    Register-AzProviderFeature -FeatureName "anfDatastoreExperience" -ProviderNamespace "Microsoft.AVS"

    # Confirm all features are 'Registered'
    #Get-AzProviderFeature -FeatureName "anfavsdatastore" -ProviderNamespace "Microsoft.NetApp"
    #Get-AzProviderFeature -FeatureName "cloudsanexperience" -ProviderNamespace "Microsoft.AVS"
    #Get-AzProviderFeature -FeatureName "anfdatastoreexperience" -ProviderNamespace "Microsoft.AVS"
    #Get-AzProviderFeature -ProviderNamespace Microsoft.NetApp -FeatureName ANFSDNAppliance
    #Get-AzProviderFeature -ProviderNamespace Microsoft.Network -FeatureName AllowPoliciesOnBareMetal

    # Create Azure NetApp Files 'Delegated Subnet'
    $anfdelegation = New-AzDelegation -Name "anfDelegation" -ServiceName "Microsoft.Netapp/volumes" 
    $vnet = Get-AzVirtualNetwork -Name $anfVnet -ResourceGroupName $anfVnetResourceGroup
    write-host "Creating ANF Delegated Subnet..."
    Add-AzVirtualNetworkSubnetConfig -Name $anfSubnet -VirtualNetwork $vnet -AddressPrefix $anfSubnetPrefix -Delegation $anfdelegation -WarningAction:SilentlyContinue -EA SilentlyContinue | Set-AzVirtualNetwork

    # Get subnetId of newly created ANF delegated subnet
    $vnet = Get-AzVirtualNetwork -Name $anfVnet -ResourceGroupName $anfVnetResourceGroup
    $subnetId = ($vnet | Get-AzVirtualNetworkSubnetconfig | Where-Object Name -eq $anfSubnet).id
    while(!($subnetId)){
        start-sleep -seconds 15
        write-host "Fetching subnet ID of newly created delegated subnet..."
        $subnetId = ($vnet | Get-AzVirtualNetworkSubnetconfig | Where-Object Name -eq $anfSubnet).id
    }

    # Create Azure NetApp Files 'NetApp Account'
    write-host "Creating ANF NetApp Account..."
    New-AzNetAppFilesAccount -ResourceGroupName $anfResourceGroup -Location $anfLocation -Name $anfAccount

    # Create Azure NetApp Files 'Capacity Pool'
    write-host "Creating ANF Capacity Pool..."
    $anfPoolSizeBytes = $anfPoolSize*1024*1024*1024*1024
    New-AzNetAppFilesPool -ResourceGroupName $anfResourceGroup -Location $anfLocation -AccountName $anfAccount -Name $anfPool -PoolSize $anfPoolSizeBytes -ServiceLevel $anfPoolServiceLevel

    # Create Azure NetApp Files 'Volume'
    write-host "Creating ANF Volume..."
    $anfVolumeSizeBytes = $anfVolumeSize*1024*1024*1024*1024
    New-AzNetAppFilesVolume -ResourceGroupName $anfResourceGroup -NetworkFeature Standard -Location $anfLocation -AccountName $anfAccount -PoolName $anfPool -Name $anfVolume -UsageThreshold $anfVolumeSizeBytes -SubnetId $subnetId -CreationToken $anfVolume -ServiceLevel $anfPoolServiceLevel -ProtocolType NFSv3 -AvsDataStore Enabled

    # Attach ANF volume as AVS datastore
    write-host "Attaching the volume as datastore..."
    #write-host "az vmware datastore netapp-volume create --name"$anfVolume "--resource-group"$privateCloudResourceGroup "--cluster Cluster-1 --private-cloud"$privateCloud "--volume-id" $volumeObject.id
    $dataStoreURI = '/subscriptions/' + $subId + '/resourceGroups/' + $privateCloudResourceGroup + '/providers/Microsoft.AVS/privateClouds/' + $privateCloud + '/clusters/Cluster-1/datastores/' + $anfVolume + '?api-version=2021-12-01'
    $payload = '{"properties": {"netAppVolume": {"id": "/subscriptions/' + $subId + '/resourceGroups/' + $anfResourceGroup + '/providers/Microsoft.NetApp/netAppAccounts/' + $anfAccount + '/capacityPools/' + $anfPool + '/volumes/' + $anfVolume + '"}}}'
    $createParams = @{
        Path = $dataStoreURI
        Payload = $payload
        Method = 'PUT'
    }
    Invoke-AzRestMethod @createParams

} elseif($action -eq "cleanup") {
    write-host "Getting list of all volumes in"$anfResourceGroup"/"$anfAccount"/"$anfPool"..."
    $allVolumes = Get-AzResource | Where-Object {$_.ResourceType -eq "Microsoft.NetApp/netAppAccounts/capacityPools/volumes"}
    foreach($volume in $allvolumes){
        $volumeDetails = Get-AzNetAppFilesVolume -ResourceId $volume.Id
        if($volumeDetails.AvsDataStore -eq 'Enabled'){
            write-host "Detaching volume from AVS private cloud..."
            $dataStoreURI = '/subscriptions/' + $subId + '/resourceGroups/' + $privateCloudResourceGroup + '/providers/Microsoft.AVS/privateClouds/' + $privateCloud + '/clusters/Cluster-1/datastores/' + $volumeDetails.CreationToken + '?api-version=2021-12-01'
            $deleteParams = @{
                Path = $dataStoreURI
                Method = 'DELETE'
            }
            Invoke-AzRestMethod @deleteParams
            Start-Sleep -Seconds 60
        }
        write-host "Deleting volume,"$volume.Name"..."
        Remove-AzNetAppFilesVolume -ResourceId $volume.ResourceId
    }
    while($allVolumes){
        Start-Sleep -Seconds 30
        $allVolumes = Get-AzResource | Where-Object {$_.ResourceType -eq "Microsoft.NetApp/netAppAccounts/capacityPools/volumes"}
    }
    write-host "Deleting capacity pool,"$anfPool"..."
    Remove-AzNetAppFilesPool -ResourceGroupName $anfResourceGroup -AccountName $anfAccount -Name $anfPool
    write-host "Deleting NetApp account,"$anfAccount"..."
    Remove-AzNetAppFilesAccount -ResourceGroupName $anfResourceGroup -Name $anfAccount
    $vnet = Get-AzVirtualNetwork -Name $anfVnet -ResourceGroupName $anfVnetResourceGroup
    $subnetId = ($vnet | Get-AzVirtualNetworkSubnetconfig | Where-Object Name -eq $anfSubnet).id
    write-host "Deleting ANF delegated subnet..."
    Remove-AzVirtualNetworkSubnetConfig -Name $anfSubnet -VirtualNetwork $vnet | Set-AzVirtualNetwork
}

if($action -eq "list") {
    # List AVS datastores
    write-host "Listing all AVS datastores..."
    $datastoreObjects = @()
    $dataStoreURI = '/subscriptions/' + $subId + '/resourceGroups/' + $privateCloudResourceGroup + '/providers/Microsoft.AVS/privateClouds/' + $privateCloud + '/clusters/Cluster-1/datastores?api-version=2021-12-01'
    $listParams = @{
        Path = $dataStoreURI
        Method = 'GET'
    }
    $rawData = (Invoke-AzRestMethod @listParams).Content
    $objectData = ConvertFrom-Json $rawData
    foreach($datastore in $objectData.value) {
        $volumeDetail = Get-AzNetAppFilesVolume -ResourceId $datastore.properties.netAppVolume.Id
        $datastoreCustomObject = [PSCustomObject]@{
            datastoreId = $datastore.Id
            privateCloud = $datastore.Id.split('/')[8]
            cluster = $datastore.Id.split('/')[10]
            datastore = $datastore.Id.split('/')[12]
            volume = $volumeDetail.name.split('/')[2]
            capacityPool = $volumeDetail.name.split('/')[1]
            netappAccount = $volumeDetail.name.split('/')[0]
            Location = $volumeDetail.Location
            provisionedSize = $volumeDetail.UsageThreshold/1024/1024/1024
            ResourceID = $volumeDetail.Id
            SubnetId = $volumeDetail.SubnetId
            Tags = $volumeDetail.Tags
            AvsDataStore = $volumeDetail.AvsDataStore
        }
        $datastoreObjects += $datastoreCustomObject
    }
$datastoreObjects | select-object datastore,privateCloud,cluster,provisionedSize
}

