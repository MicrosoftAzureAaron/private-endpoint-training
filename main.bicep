// Revision number for tracking deployments
var bicepRevision = '0.3.5' //added as tag on each resource to track deployment version

// Parameters
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
@allowed([
  'Standard_B2pls_v2'
  'Standard_B2ps_v2'
  'Standard_B2pts_v2'
  'Standard_B4pls_v2'
  'Standard_B4ps_v2'
])
param vmSize string = 'Standard_B2ps_v2'

// Variables
// Network Variables
var vnetName = 'training-vnet'
var vnetAddressPrefix = '10.0.0.0/16'
var azureFirewallSubnetName = 'AzureFirewallSubnet'
var firewallSubnetPrefix = '10.0.0.0/24'
var vm1SubnetName = 'VM1Subnet'
var vm1SubnetPrefix = '10.0.1.0/24'
var vm2SubnetName = 'VM2Subnet'
var vm2SubnetPrefix = '10.0.2.0/24'
var vm3SubnetName = 'VM3Subnet'
var vm3SubnetPrefix = '10.0.3.0/24'
var vm4SubnetName = 'VM4Subnet'
var vm4SubnetPrefix = '10.0.4.0/24'
var vm5SubnetName = 'VM5Subnet'
var vm5SubnetPrefix = '10.0.5.0/24'
var peSubnetName = 'PESubnet'
var peSubnetPrefix = '10.0.255.0/24'
var routeTableVm1Name = 'rt-vm1'
var routeTableVm2Name = 'rt-vm2'
var routeTableVm3Name = 'rt-vm3'
var routeTableVm4Name = 'rt-vm4'
var routeTableVm5Name = 'rt-vm5'
var peSubnetLastIp = '10.0.255.254'

// Compute Variables
var vm1Name = 'training-vm1'
var vm2Name = 'training-vm2'
var vm3Name = 'training-vm3'
var vm4Name = 'training-vm4'
var vm5Name = 'training-vm5'
var imagePublisher = 'Canonical'
var imageOffer = '0001-com-ubuntu-server-jammy'
var imageSku = '22_04-lts-arm64'
var imageVersion = 'latest'

// Security Variables
var firewallName = 'training-firewall'
var firewallPolicyName = 'training-firewall-policy'
var firewallPrivateIp = '10.0.0.4'

// Storage Variables
var storageAccountName = 'trngstor${uniqueString(resourceGroup().id)}'

// DNS Variables
var dnsZoneName = 'privatelink.file.${environment().suffixes.storage}'

// Private Endpoint Variables
var privateEndpointName = 'training-pe'

// Resources

// Storage Account with File service enabled
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vm3SubnetName)
        }
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vm4SubnetName)
        }
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vm5SubnetName)
        }
      ]
    }
    isHnsEnabled: false
  }
  dependsOn: [
    vnet
  ]
}

// Route Tables for VMs
resource routeTableVm1 'Microsoft.Network/routeTables@2023-09-01' = {
  name: routeTableVm1Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource routeTableVm2 'Microsoft.Network/routeTables@2023-09-01' = {
  name: routeTableVm2Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'pe-to-firewall'
        properties: {
          addressPrefix: peSubnetPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource routeTableVm3 'Microsoft.Network/routeTables@2023-09-01' = {
  name: routeTableVm3Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource routeTableVm4 'Microsoft.Network/routeTables@2023-09-01' = {
  name: routeTableVm4Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'storage-to-firewall'
        properties: {
          addressPrefix: 'Storage'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

resource routeTableVm5 'Microsoft.Network/routeTables@2023-09-01' = {
  name: routeTableVm5Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

// 5 VMs in different subnets
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: azureFirewallSubnetName
        properties: {
          addressPrefix: firewallSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: vm1SubnetName
        properties: {
          addressPrefix: vm1SubnetPrefix
          routeTable: {
            id: routeTableVm1.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: vm2SubnetName
        properties: {
          addressPrefix: vm2SubnetPrefix
          routeTable: {
            id: routeTableVm2.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: vm3SubnetName
        properties: {
          addressPrefix: vm3SubnetPrefix
          routeTable: {
            id: routeTableVm3.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: vm4SubnetName
        properties: {
          addressPrefix: vm4SubnetPrefix
          routeTable: {
            id: routeTableVm4.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: vm5SubnetName
        properties: {
          addressPrefix: vm5SubnetPrefix
          routeTable: {
            id: routeTableVm5.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: peSubnetPrefix
          privateEndpointNetworkPolicies: 'RouteTableEnabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource vm1Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vm1Name}-nic'
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

resource vm2Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vm2Name}-nic'
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[2].id
          }
        }
      }
    ]
  }
}

resource vm3Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vm3Name}-nic'
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[3].id
          }
        }
      }
    ]
  }
}

resource vm4Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vm4Name}-nic'
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[4].id
          }
        }
      }
    ]
  }
}

resource vm5Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vm5Name}-nic'
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[5].id
          }
        }
      }
    ]
  }
}

resource vm1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm1Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm1Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm1Nic.id
        }
      ]
    }
  }
}

resource vm2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm2Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm2Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm2Nic.id
        }
      ]
    }
  }
}

resource vm3 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm3Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm3Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm3Nic.id
        }
      ]
    }
  }
}

resource vm4 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm4Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm4Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm4Nic.id
        }
      ]
    }
  }
}

resource vm5 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm5Name
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm5Name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vm5Nic.id
        }
      ]
    }
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'firewall-pip'
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: firewallName
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'firewall-ipconfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: azureFirewallAllowPolicy.outputs.firewallPolicyId
    }
  }
}

module azureFirewallAllowPolicy 'AzureFirewallAllowPolicy.bicep' = {
  name: 'azureFirewallAllowPolicy'
  params: {
    firewallPolicyName: firewallPolicyName
  }
}

// Private DNS Zone for Storage Account private endpoint
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: dnsZoneName
  location: 'global'
  tags: {
    bicepRevision: string(bicepRevision)
  }
}

// Private DNS A record for the storage account's private endpoint
resource privateDnsARecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  name: '${storageAccountName}.${dnsZoneName}'
  parent: privateDnsZone
  properties: {
    aRecords: [
      {
        ipv4Address: peSubnetLastIp
      }
    ]
    ttl: 3600
  }
}

resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'vnet-link'
  location: 'global'
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', vnetName)
    }
    registrationEnabled: false
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: privateEndpointName
  location: location
  tags: {
    bicepRevision: string(bicepRevision)
  }
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'PESubnet')
    }
    customNetworkInterfaceName: '${privateEndpointName}-nic'
    ipConfigurations: [
      {
        name: 'pe-ipconfig'
        properties: {
          privateIPAddress: peSubnetLastIp
          groupId: 'file'
          memberName: 'file'
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'storageAccountFileConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['file']
        }
      }
    ]
  }
}

