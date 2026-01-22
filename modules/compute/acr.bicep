// =========================================
// AZURE CONTAINER REGISTRY (ACR) MODULE
// =========================================
// This module creates:
// - Azure Container Registry
// - Private endpoint for secure VNet integration
// - Admin user access (optional)
// - System-assigned managed identity
// - Following ACR best practices
// =========================================

metadata description = 'Deploys Azure Container Registry with private endpoint support'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the Azure Container Registry')
@minLength(5)
@maxLength(50)
param acrName string

@description('Azure region for the ACR')
param location string = resourceGroup().location

@description('ACR SKU tier')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Standard'

@description('Enable admin user for ACR')
param enableAdminUser bool = false

@description('Enable public network access')
param publicNetworkAccess bool = true

@description('Subnet resource ID for private endpoint')
param subnetId string

@description('Enable private endpoint for ACR')
param enablePrivateEndpoint bool = false

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable zone redundancy (Premium SKU only)')
param zoneRedundancy bool = false

@description('Enable content trust (image signing)')
param enableContentTrust bool = false

@description('Retention policy in days (0 = disabled, Premium SKU only)')
@minValue(0)
@maxValue(365)
param retentionDays int = 7

@description('Enable quarantine policy (Premium SKU only)')
param enableQuarantinePolicy bool = false

@description('Enable anonymous pull access')
param enableAnonymousPullAccess bool = false

@description('Enable data endpoint (Premium SKU only)')
param enableDataEndpoint bool = false

// =========================================
// VARIABLES
// =========================================

var privateEndpointName = 'pe-${acrName}'
var privateDnsZoneName = 'privatelink.azurecr.io'
var pvtEndpointDnsGroupName = '${privateEndpointName}/default'

// =========================================
// RESOURCES
// =========================================

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: enableAdminUser
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: (acrSku == 'Premium' && zoneRedundancy) ? 'Enabled' : 'Disabled'
    dataEndpointEnabled: (acrSku == 'Premium' && enableDataEndpoint) ? true : false
    policies: {
      quarantinePolicy: {
        status: (acrSku == 'Premium' && enableQuarantinePolicy) ? 'enabled' : 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: (acrSku == 'Premium' && enableContentTrust) ? 'enabled' : 'disabled'
      }
      retentionPolicy: {
        days: (acrSku == 'Premium' && retentionDays > 0) ? retentionDays : 7
        status: (acrSku == 'Premium' && retentionDays > 0) ? 'enabled' : 'disabled'
      }
      exportPolicy: {
        status: 'enabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
  }
}

// Private Endpoint for ACR
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (enablePrivateEndpoint && acrSku == 'Premium') {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone for ACR
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (enablePrivateEndpoint && acrSku == 'Premium') {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

// Private DNS Zone Group
resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (enablePrivateEndpoint && acrSku == 'Premium') {
  name: pvtEndpointDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}

// =========================================
// OUTPUTS
// =========================================

@description('ACR resource ID')
output acrId string = containerRegistry.id

@description('ACR name')
output acrName string = containerRegistry.name

@description('ACR login server')
output acrLoginServer string = containerRegistry.properties.loginServer

@description('ACR managed identity principal ID')
output acrPrincipalId string = containerRegistry.identity.principalId

@description('Private endpoint ID')
output privateEndpointId string = enablePrivateEndpoint && acrSku == 'Premium' ? privateEndpoint.id : ''

@description('Private DNS zone ID')
output privateDnsZoneId string = enablePrivateEndpoint && acrSku == 'Premium' ? privateDnsZone.id : ''
