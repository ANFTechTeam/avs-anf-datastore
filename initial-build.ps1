param (
    [string]$action
)

#$privateClouds = @('01', '02', '03')
$privateClouds = @('03')

# set environment variables
$privateCloudResourceGroup = "AVS-VMwareExplore-HOL-PC"
$privateCloudName = "AVS-VMwareExplore-HOL-PC"
$anfVnet = "vnet-HOL-PC" #this vnet must be peered to the AVS vnet
$anfVnetResourceGroup = "AVS-VMwareExplore-HOL-PC" #this must be an existing resource group
$anfSubnet = "ANFSubnet"
$anfSubnetPrefix = "10.3.2.0/24"
$anfResourceGroup = "AVS-VMwareExplore-HOL-PC" #this must be an existing resource group
$anfLocation = "westeurope"
$anfAccount = "AVS-VMwareExplore-HOL-ANFNA-"
$anfPool = "AVS-VMwareExplore-HOL-ANFPool-"
$anfPoolSize = 4 #tebibytes
$anfPoolServiceLevel = "Premium"
$anfVolume = "anfDatastore000"
$anfVolumeSize = 1 #tebibytes

Set-AzContext -subscriptionid abf039b4-3e19-40ad-a85e-93937bd8a4bc

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

    
    foreach($privateCloud in $privateClouds) {
        # Create Azure NetApp Files 'Delegated Subnet'
        $anfdelegation = New-AzDelegation -Name "anfDelegation" -ServiceName "Microsoft.Netapp/volumes" 
        $vnet = Get-AzVirtualNetwork -Name $anfVnet$privateCloud -ResourceGroupName $anfVnetResourceGroup$privateCloud
        write-host "Creating ANF Delegated Subnet..."
        Add-AzVirtualNetworkSubnetConfig -Name $anfSubnet -VirtualNetwork $vnet -AddressPrefix $anfSubnetPrefix -Delegation $anfdelegation -WarningAction:SilentlyContinue -EA SilentlyContinue | Set-AzVirtualNetwork

        # Get subnetId of newly created ANF delegated subnet
        $vnet = Get-AzVirtualNetwork -Name $anfVnet$privateCloud -ResourceGroupName $anfVnetResourceGroup$privateCloud
        $subnetId = ($vnet | Get-AzVirtualNetworkSubnetconfig | Where-Object Name -eq $anfSubnet).id
        while(!($subnetId)){
            start-sleep -seconds 15
            write-host "Fetching subnet ID of newly created delegated subnet..."
            $subnetId = ($vnet | Get-AzVirtualNetworkSubnetconfig | Where-Object Name -eq $anfSubnet).id
        }

        # Create Azure NetApp Files 'NetApp Account'
        write-host "Creating ANF NetApp Account..."
        New-AzNetAppFilesAccount -ResourceGroupName $anfResourceGroup$privateCloud -Location $anfLocation -Name $anfAccount$privateCloud

        # Create Azure NetApp Files 'Capacity Pool'
        write-host "Creating ANF Capacity Pool..."
        $anfPoolSizeBytes = $anfPoolSize*1024*1024*1024*1024
        New-AzNetAppFilesPool -ResourceGroupName $anfResourceGroup$privateCloud -Location $anfLocation -AccountName $anfAccount$privateCloud -Name $anfPool$privateCloud -PoolSize $anfPoolSizeBytes -ServiceLevel $anfPoolServiceLevel

        # Create Azure NetApp Files 'Volume'
        write-host "Creating ANF Volume..."
        $anfVolumeSizeBytes = $anfVolumeSize*1024*1024*1024*1024
        New-AzNetAppFilesVolume -ResourceGroupName $anfResourceGroup$privateCloud -NetworkFeature Standard -Location $anfLocation -AccountName $anfAccount$privateCloud -PoolName $anfPool$privateCloud -Name $anfVolume -UsageThreshold $anfVolumeSizeBytes -SubnetId $subnetId -CreationToken $anfVolume -ServiceLevel $anfPoolServiceLevel -ProtocolType NFSv3 -AvsDataStore Enabled

        # Attach ANF volume as AVS datastore
        write-host "Attaching the volume as datastore..."
        #write-host "az vmware datastore netapp-volume create --name"$anfVolume "--resource-group"$privateCloudResourceGroup "--cluster Cluster-1 --private-cloud"$privateCloud "--volume-id" $volumeObject.id
        $dataStoreURI = '/subscriptions/' + $subId + '/resourceGroups/' + $privateCloudResourceGroup+$privateCloud + '/providers/Microsoft.AVS/privateClouds/' + $privateCloudName+$privateCloud + '/clusters/Cluster-1/datastores/' + $anfVolume + '?api-version=2021-12-01'
        $payload = '{"properties": {"netAppVolume": {"id": "/subscriptions/' + $subId + '/resourceGroups/' + $anfResourceGroup+$privateCloud + '/providers/Microsoft.NetApp/netAppAccounts/' + $anfAccount+$privateCloud + '/capacityPools/' + $anfPool+$privateCloud + '/volumes/' + $anfVolume + '"}}}'
        $createParams = @{
            Path = $dataStoreURI
            Payload = $payload
            Method = 'PUT'
        }
        Invoke-AzRestMethod @createParams
    }
} elseif($action -eq "cleanup") {
    foreach($privateCloud in $privateClouds) {
        write-host "Getting list of all volumes in"$anfResourceGroup$privateCloud"/"$anfAccount$privateCloud"/"$anfPool$privateCloud"..."
        $allVolumes = Get-AzResource | Where-Object {$_.ResourceType -eq "Microsoft.NetApp/netAppAccounts/capacityPools/volumes" -and $_.ResourceGroupName -eq $privateCloudResourceGroup+$privateCloud}
        foreach($volume in $allvolumes){
            $volumeDetails = Get-AzNetAppFilesVolume -ResourceId $volume.Id
            if($volumeDetails.AvsDataStore -eq 'Enabled'){
                write-host 'Detaching volume,'$volumeDetails.Name'from AVS private cloud...'
                $dataStoreURI = '/subscriptions/' + $subId + '/resourceGroups/' + $privateCloudResourceGroup+$privateCloud + '/providers/Microsoft.AVS/privateClouds/' + $privateCloudName+$privateCloud + '/clusters/Cluster-1/datastores/' + $volumeDetails.CreationToken + '?api-version=2021-12-01'
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
            $allVolumes = Get-AzResource | Where-Object {$_.ResourceType -eq "Microsoft.NetApp/netAppAccounts/capacityPools/volumes" -and $_.ResourceGroupName -eq $privateCloudResourceGroup+$privateCloud}
        }
        write-host "Deleting capacity pool,"$anfPool$privateCloud"..."
        Remove-AzNetAppFilesPool -ResourceGroupName $anfResourceGroup$privateCloud -AccountName $anfAccount$privateCloud -Name $anfPool$privateCloud
        write-host "Deleting NetApp account,"$anfAccount$privateCloud"..."
        Remove-AzNetAppFilesAccount -ResourceGroupName $anfResourceGroup$privateCloud -Name $anfAccount$privateCloud
        $vnet = Get-AzVirtualNetwork -Name $anfVnet$privateCloud -ResourceGroupName $anfVnetResourceGroup$privateCloud
        $subnetId = ($vnet | Get-AzVirtualNetworkSubnetconfig | Where-Object Name -eq $anfSubnet).id
        write-host "Deleting ANF delegated subnet..."
        Remove-AzVirtualNetworkSubnetConfig -Name $anfSubnet -VirtualNetwork $vnet | Set-AzVirtualNetwork
    }
} elseif($action -eq "list") {
    foreach($privateCloud in $privateClouds) {
        # List AVS datastores
        write-host "Listing all AVS datastores..."
        $datastoreObjects = @()
        $dataStoreURI = '/subscriptions/' + $subId + '/resourceGroups/' + $privateCloudResourceGroup+$privateCloud + '/providers/Microsoft.AVS/privateClouds/' + $privateCloudName+$privateCloud + '/clusters/Cluster-1/datastores?api-version=2021-12-01'
        $listParams = @{
            Path = $dataStoreURI
            Method = 'GET'
        }
        $rawData = (Invoke-AzRestMethod @listParams).Content
        $objectData = ConvertFrom-Json $rawData
        foreach($datastore in $objectData.value) {
            $datastore.properties.netAppVolume.Id
        }
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
}

