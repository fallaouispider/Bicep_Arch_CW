// =========================================
// VIRTUAL NETWORK MODULE
// =========================================
// This module creates:
// - Network Security Group with baseline security rules
// - Virtual Network with specified address space
// - Subnet with NSG association
// Following Azure networking best practices
// =========================================

metadata description = 'Deploys Virtual Network with Subnet and Network Security Group'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the Virtual Network')
@minLength(2)
@maxLength(64)
param vnetName string

@description('Azure region for the Virtual Network')
param location string = resourceGroup().location

@description('Virtual Network address space in CIDR notation')
param vnetAddressPrefix string

@description('Name of the Subnet')
@minLength(1)
@maxLength(80)
param subnetName string

@description('Subnet address space in CIDR notation')
param subnetAddressPrefix string

@description('Name of the Application Gateway Subnet')
@minLength(1)
@maxLength(80)
param appGatewaySubnetName string

@description('Application Gateway subnet address space in CIDR notation')
param appGatewaySubnetAddressPrefix string

@description('Name of the Network Security Group')
@minLength(1)
@maxLength(80)
param nsgName string

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable diagnostic settings for network resources')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

// =========================================
// RESOURCES
// =========================================

@description('Network Security Group with baseline security rules')
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          description: 'Allow inbound HTTPS traffic from Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          description: 'Allow inbound HTTP traffic from Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSSHInbound'
        properties: {
          description: 'Allow SSH from Azure Bastion subnet (update source as needed)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowRDPInbound'
        properties: {
          description: 'Allow RDP from Azure Bastion subnet (update source as needed)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowVnetOutbound'
        properties: {
          description: 'Allow outbound traffic within VNet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowInternetOutbound'
        properties: {
          description: 'Allow outbound traffic to Internet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          description: 'Allow outbound traffic to Azure services'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
    ]
  }
}

@description('Network Security Group for Application Gateway subnet')
resource appGatewayNSG 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${nsgName}-appgw'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowGatewayManager'
        properties: {
          description: 'Allow inbound traffic from Azure Gateway Manager'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          description: 'Allow inbound traffic from Azure Load Balancer'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpsInbound'
        properties: {
          description: 'Allow inbound HTTPS traffic from Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          description: 'Allow inbound HTTP traffic from Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'Deny all other inbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutbound'
        properties: {
          description: 'Allow all outbound traffic'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
    ]
  }
}

@description('Diagnostic settings for Network Security Group')
resource nsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${nsgName}-diagnostics'
  scope: networkSecurityGroup
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

@description('Diagnostic settings for Application Gateway Network Security Group')
resource appGatewayNsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${nsgName}-appgw-diagnostics'
  scope: appGatewayNSG
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

@description('Virtual Network with specified address space')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

@description('Diagnostic settings for Virtual Network')
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${vnetName}-diagnostics'
  scope: virtualNetwork
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

@description('Subnet with Network Security Group association')
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: subnetName
  parent: virtualNetwork
  properties: {
    addressPrefix: subnetAddressPrefix
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    serviceEndpoints: [
      {
        service: 'Microsoft.AzureCosmosDB'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.ServiceBus'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Sql'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.ApiManagement'
        locations: [
          location
        ]
      }
    ]
  }
}

@description('Application Gateway subnet with dedicated NSG')
resource appGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: appGatewaySubnetName
  parent: virtualNetwork
  properties: {
    addressPrefix: appGatewaySubnetAddressPrefix
    networkSecurityGroup: {
      id: appGatewayNSG.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    subnet
  ]
}

// =========================================
// OUTPUTS
// =========================================

@description('The resource ID of the Virtual Network')
output vnetId string = virtualNetwork.id

@description('The name of the Virtual Network')
output vnetName string = virtualNetwork.name

@description('The address prefix of the Virtual Network')
output vnetAddressPrefix string = virtualNetwork.properties.addressSpace.addressPrefixes[0]

@description('The resource ID of the Subnet')
output subnetId string = subnet.id

@description('The name of the Subnet')
output subnetName string = subnet.name

@description('The address prefix of the Subnet')
output subnetAddressPrefix string = subnet.properties.addressPrefix

@description('The resource ID of the Network Security Group')
output nsgId string = networkSecurityGroup.id

@description('The name of the Network Security Group')
output nsgName string = networkSecurityGroup.name

@description('The resource ID of the Application Gateway Subnet')
output appGatewaySubnetId string = appGatewaySubnet.id

@description('The name of the Application Gateway Subnet')
output appGatewaySubnetName string = appGatewaySubnet.name

@description('The address prefix of the Application Gateway Subnet')
output appGatewaySubnetAddressPrefix string = appGatewaySubnet.properties.addressPrefix

@description('The resource ID of the Application Gateway NSG')
output appGatewayNsgId string = appGatewayNSG.id

@description('The name of the Application Gateway NSG')
output appGatewayNsgName string = appGatewayNSG.name
