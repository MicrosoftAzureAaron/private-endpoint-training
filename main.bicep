// Revision number for tracking deployments
var bicepRevision = '0.2.7'  

// Parameters
param location string = resourceGroup().location
param vnetName string = 'training-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param firewallSubnetPrefix string = '10.0.0.0/24'
param vm1SubnetPrefix string = '10.0.1.0/24'
param vm2SubnetPrefix string = '10.0.2.0/24'
param peSubnetPrefix string = '10.0.3.0/24'
param routeTableVm1Name string = 'rt-vm1'
param routeTableVm2Name string = 'rt-vm2'
param vm1Name string = 'training-vm1'
param vm2Name string = 'training-vm2'
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
param firewallName string = 'training-firewall'
param firewallPrivateIp string = '10.0.0.4'
param dnsZoneName string = 'privatelink.file.${environment().suffixes.storage}'
param privateEndpointName string = 'training-pe'
param storageAccountName string = 'trngstor${uniqueString(resourceGroup().id)}'

// Variables
var imagePublisher = 'Canonical'
var imageOffer = '0001-com-ubuntu-server-jammy'
var imageSku = '22_04-lts-arm64'
var imageVersion = 'latest'

//last IP in PE subnet
var peSubnetLastIp = '10.0.3.254' 

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
					// Use a parameter for the firewall private IP to break the cycle
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

// Two VMs in different subnets
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
				name: 'AzureFirewallSubnet'
				properties: {
					addressPrefix: firewallSubnetPrefix
				}
			}
			{
				name: 'VM1Subnet'
				properties: {
					addressPrefix: vm1SubnetPrefix
					routeTable: {
						id: routeTableVm1.id
					}
				}
			}
			{
				name: 'VM2Subnet'
				properties: {
					addressPrefix: vm2SubnetPrefix
					privateEndpointNetworkPolicies: 'Enabled'
					routeTable: {
						id: routeTableVm2.id
					}
				}
			}
			{
				name: 'PESubnet'
				properties: {
					addressPrefix: peSubnetPrefix
					privateEndpointNetworkPolicies: 'Enabled'
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
			id: firewallPolicy.id
		}
	}
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = {
	name: '${firewallName}-policy'
	location: location
	tags: {
		bicepRevision: string(bicepRevision)
	}
	properties: {}
}

// Define rule collection group as a child resource
resource firewallPolicyRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
	name: 'PETrainingRuleCollectionGroup'
	parent: firewallPolicy
	properties: {
		ruleCollections: [
			{
				name: 'AllowAnyAny'
				ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
				priority: 100
				action: {
					type: 'Allow'
				}
				rules: [
					{
						name: 'AllowAnyAnyRule'
						ruleType: 'NetworkRule'
						sourceAddresses: ['*']
						destinationAddresses: ['*']
						destinationPorts: ['*']
						ipProtocols: ['Any']
					}
				]
			}
		]
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
		}
		isHnsEnabled: false
  }
}
