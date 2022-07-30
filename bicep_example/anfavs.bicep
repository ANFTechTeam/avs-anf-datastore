param existingVNetName string
param netappDelegatedSubnetName string
param netappAccountName string
param netappAccountLocation string
param netappCapacityPoolName string
param netappCapacityPoolServiceLevel string
param netappCapacityPoolSize int
param netappVolumeName string
param netappVolumeSize int

param avsPrivateCloudName string
param avsPrivateCloudClusterName string

@description('import the existing Azure VNet')
resource netappVNet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: existingVNetName
}

@description('import the existing AVS private cloud')
resource avsPrivateCloud 'Microsoft.AVS/privateClouds@2021-12-01' existing = {
  name: avsPrivateCloudName
}

@description('import the existing AVS private cloud cluster')
resource avsPrivateCloudCluster 'Microsoft.AVS/privateClouds/clusters@2021-12-01' existing = {
  parent: avsPrivateCloud
  name: avsPrivateCloudClusterName
}

@description('create Azure NetApp files delegated subnet')
resource netappDelegatedSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  name: netappDelegatedSubnetName
  parent: netappVNet
  properties: {
    delegations: [
      {
        name: 'microsoftnetapp'
        properties: {
          serviceName: 'Microsoft.Netapp/volumes'
        }
      }
    ]
    addressPrefix: '10.3.2.0/24'
  }
}

@description('create Azure NetApp Files account')
resource netappAccount 'Microsoft.NetApp/netAppAccounts@2022-01-01' = { 
    name: netappAccountName
    location: netappAccountLocation 
}

@description('create Azure NetApp Files capacity pool')
resource netappCapacityPool 'Microsoft.NetApp/netAppAccounts/capacityPools@2022-01-01' = {
  name: netappCapacityPoolName
  location: netappAccountLocation
  parent: netappAccount
  properties: {
    coolAccess: false
    qosType: 'Auto'
    serviceLevel: netappCapacityPoolServiceLevel
    size: netappCapacityPoolSize
  }
}

@description('create Azure NetApp Files volume')
resource netappVolume 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes@2022-01-01' = {
  name: netappVolumeName
  location: netappAccountLocation
  parent: netappCapacityPool
  properties: {
    avsDataStore: 'Enabled'
    creationToken: netappVolumeName
    exportPolicy: {
      rules: [
        {
          allowedClients: '0.0.0.0/0'
          chownMode: 'restricted'
          cifs: false
          hasRootAccess: true
          nfsv3: true
          nfsv41: false
          ruleIndex: 1
          unixReadWrite: true
        }
      ]
    }
    networkFeatures: 'Standard'
    protocolTypes: ['NFSv3']
    serviceLevel: netappCapacityPoolServiceLevel
    subnetId: netappDelegatedSubnet.id
    usageThreshold: netappVolumeSize
  }
}

@description('create AVS datastore from ANF volume')
resource avsDatastore 'Microsoft.AVS/privateClouds/clusters/datastores@2021-12-01' = {
  name: netappVolumeName
  parent: avsPrivateCloudCluster
  properties: {
    netAppVolume: {
      id: netappVolume.id
    }
  }
}
