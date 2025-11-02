// Route tables for subnets
param routeTableVm1Name string = 'rt-vm1'
param routeTableVm2Name string = 'rt-vm2'

resource routeTableVm1 'Microsoft.Network/routeTables@2023-09-01' = {
	name: routeTableVm1Name
	location: location
	properties: {
		disableBgpRoutePropagation: false
		routes: [
			{
				name: 'default-to-firewall'
				properties: {
					addressPrefix: '0.0.0.0/0'
					nextHopType: 'VirtualAppliance'
					nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
				}
			}
		]
	}
}

resource routeTableVm2 'Microsoft.Network/routeTables@2023-09-01' = {
	name: routeTableVm2Name
	location: location
	properties: {
		disableBgpRoutePropagation: false
		routes: [
			{
				name: 'pe-to-firewall'
				properties: {
					addressPrefix: privateEndpoint.properties.subnet.id
					nextHopType: 'VirtualAppliance'
					nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
				}
			}
		]
	}
}

resource vm1Subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'VM1Subnet'
}

resource vm1SubnetRouteTableAssoc 'Microsoft.Network/virtualNetworks/subnets/routeTable@2023-09-01' = {
  parent: vm1Subnet
  name: 'routeTable'
  properties: {
	routeTable: {
	  id: routeTableVm1.id
	}
  }
}

resource vm2Subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'VM2Subnet'
}

resource vm2SubnetRouteTableAssoc 'Microsoft.Network/virtualNetworks/subnets/routeTable@2023-09-01' = {
	parent: vm2Subnet
	name: 'routeTable'
	properties: {
		routeTable: {
			id: routeTableVm2.id
		}
	}
}
// Two VMs in different subnets
param vm1Name string = 'training-vm1'
param vm2Name string = 'training-vm2'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

resource vm1Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
	name: '${vm1Name}-nic'
	location: location
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
	properties: {
		hardwareProfile: {
			vmSize: 'Standard_B2s'
		}
		osProfile: {
			computerName: vm1Name
			adminUsername: adminUsername
			adminPassword: adminPassword
		}
		storageProfile: {
			imageReference: {
				publisher: 'MicrosoftWindowsServer'
				offer: 'WindowsServer'
				sku: '2019-Datacenter'
				version: 'latest'
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
	properties: {
		hardwareProfile: {
			vmSize: 'Standard_B2s'
		}
		osProfile: {
			computerName: vm2Name
			adminUsername: adminUsername
			adminPassword: adminPassword
		}
		storageProfile: {
			imageReference: {
				publisher: 'MicrosoftWindowsServer'
				offer: 'WindowsServer'
				sku: '2019-Datacenter'
				version: 'latest'
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
// Azure Firewall in dedicated subnet
param firewallName string = 'training-firewall'
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
	name: '${firewallName}-pip'
	location: location
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
	}
}
// Private DNS Zone for Storage Account private endpoint
param dnsZoneName string = 'privatelink.file.${environment().suffixes.storage}'
// For multi-cloud, use: '${environment().suffixes.storageEndpointSuffix}' if needed
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2023-05-01' = {
	name: dnsZoneName
	location: 'global'
}

resource dnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2023-05-01' = {
	parent: privateDnsZone
	name: 'vnet-link'
	location: 'global'
	properties: {
		virtualNetwork: {
			id: vnet.id
		}
		registrationEnabled: false
	}
}
// Private Endpoint for File access to Storage Account in VM2Subnet
param privateEndpointName string = 'training-pe'
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
	name: privateEndpointName
	location: location
	properties: {
		subnet: {
			id: vnet.properties.subnets[2].id
		}
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
param storageAccountName string = 'trainingstorage${uniqueString(resourceGroup().id)}'
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
	name: storageAccountName
	location: location
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
		largeFileSharesState: 'Enabled'
	}
}
// VNET with three subnets: AzureFirewallSubnet, VM1Subnet, VM2Subnet
param location string = resourceGroup().location
param vnetName string = 'training-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param firewallSubnetPrefix string = '10.0.1.0/24'
param vm1SubnetPrefix string = '10.0.2.0/24'
param vm2SubnetPrefix string = '10.0.3.0/24'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
	name: vnetName
	location: location
	properties: {
		addressSpace: {
			addressPrefixes: [vnetAddressPrefix]
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
				}
			}
			{
				name: 'VM2Subnet'
				properties: {
					addressPrefix: vm2SubnetPrefix
					privateEndpointNetworkPolicies: 'Enabled'
				}
			}
		]
	}
}
