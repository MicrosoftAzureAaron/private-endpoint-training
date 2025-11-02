// Revision number for tracking deployments
var bicepRevision = '0.1.7'  // Increment this value each time the Bicep file is updated
// Route tables for subnets
param routeTableVm1Name string = 'rt-vm1'
param routeTableVm2Name string = 'rt-vm2'

// Get the private IP address of the Azure Firewall (use a parameter to break the cycle)
param firewallPrivateIpVm1 string

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
					nextHopIpAddress: firewallPrivateIpVm1
				}
			}
		]
	}
}

param firewallPrivateIpVm2 string

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
						addressPrefix: vm2SubnetPrefix
						nextHopType: 'VirtualAppliance'
						nextHopIpAddress: firewallPrivateIpVm2
					}
				}
			]
	}
}

// The route table association is now handled inline in the VNet subnet definition.

// The route table association is now handled inline in the VNet subnet definition.
// Two VMs in different subnets
param vm1Name string = 'training-vm1'
param vm2Name string = 'training-vm2'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string
@allowed([
	'Standard_DS1_v2'
	'Standard_B2ms'
	'Standard_D2s_v3'
	'Standard_D2_v2'
	'Standard_F2s_v2'
])
param vmSize string = 'Standard_DS1_v2' // Make VM size selectable and default to a widely available size

// Select image SKU based on VM size (Gen2 for v6 SKUs, Gen1 otherwise)
var imageSku = contains(vmSize, 'v6') ? '2019-datacenter-g2' : '2019-Datacenter'

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
								publisher: 'MicrosoftWindowsServer'
								offer: 'WindowsServer'
								sku: imageSku
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
								publisher: 'MicrosoftWindowsServer'
								offer: 'WindowsServer'
								sku: imageSku
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
	}
}
// Private DNS Zone for Storage Account private endpoint
param dnsZoneName string = 'privatelink.file.${environment().suffixes.storage}'
// For multi-cloud, use: '${environment().suffixes.storageEndpointSuffix}' if needed
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
	name: dnsZoneName
		location: 'global'
		tags: {
			bicepRevision: string(bicepRevision)
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
		tags: {
			bicepRevision: string(bicepRevision)
		}
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
param storageAccountName string = 'trngstor${uniqueString(resourceGroup().id)}'
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
		tags: {
			bicepRevision: string(bicepRevision)
		}
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
				}
			}
		]
	}
}
