// =========================================
// COSMOS DB MODULE
// =========================================
// This module creates:
// - Azure Cosmos DB account (NoSQL API) with Serverless capacity mode
// - SQL Database with optional containers
// - Private endpoint for secure VNet integration
// - Following Azure best practices and Well-Architected Framework
// =========================================

metadata description = 'Deploys Azure Cosmos DB NoSQL account with Serverless capacity, database, and private endpoint'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the Cosmos DB account')
@minLength(3)
@maxLength(44)
param cosmosDbAccountName string

@description('Azure region for the Cosmos DB account')
param location string = resourceGroup().location

@description('Name of the SQL database to create')
@minLength(1)
@maxLength(255)
param databaseName string = 'appdb'

@description('Array of containers to create in the database')
param containers array = []

@description('Subnet resource ID for private endpoint')
param subnetId string

@description('Enable private endpoint for Cosmos DB')
param enablePrivateEndpoint bool = true

@description('Tags to apply to all resources')
param tags object = {}

@description('Default consistency level for the Cosmos DB account')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Enable diagnostic settings')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Disable local authentication (key-based auth)')
param disableLocalAuth bool = true

@description('Disable key-based metadata write access')
param disableKeyBasedMetadataWriteAccess bool = true

@description('Enable free tier (only one per subscription)')
param enableFreeTier bool = false

// =========================================
// RESOURCES
// =========================================

@description('Azure Cosmos DB Account with NoSQL API and Serverless capacity')
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosDbAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    enableFreeTier: enableFreeTier
    disableLocalAuth: disableLocalAuth
    disableKeyBasedMetadataWriteAccess: disableKeyBasedMetadataWriteAccess
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    networkAclBypass: 'AzureServices'
    ipRules: []
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
        tier: 'Continuous30Days'
      }
    }
    minimalTlsVersion: 'Tls12'
  }
}

@description('SQL Database for NoSQL API')
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  name: databaseName
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: databaseName
    }
  }
}

@description('SQL Containers in the database')
resource sqlContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = [for container in containers: {
  name: container.name
  parent: database
  properties: {
    resource: {
      id: container.name
      partitionKey: {
        paths: container.partitionKeyPaths
        kind: contains(container, 'partitionKeyKind') ? container.partitionKeyKind : 'Hash'
        version: contains(container, 'partitionKeyVersion') ? container.partitionKeyVersion : 2
      }
      indexingPolicy: contains(container, 'indexingPolicy') ? container.indexingPolicy : {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
      defaultTtl: contains(container, 'defaultTtl') ? container.defaultTtl : -1
      uniqueKeyPolicy: contains(container, 'uniqueKeyPolicy') ? container.uniqueKeyPolicy : {
        uniqueKeys: []
      }
      conflictResolutionPolicy: contains(container, 'conflictResolutionPolicy') ? container.conflictResolutionPolicy : {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}]

@description('Private Endpoint for Cosmos DB')
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (enablePrivateEndpoint) {
  name: '${cosmosDbAccountName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${cosmosDbAccountName}-plsc'
        properties: {
          privateLinkServiceId: cosmosDbAccount.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}

@description('Diagnostic settings for Cosmos DB account')
resource cosmosDbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${cosmosDbAccountName}-diagnostics'
  scope: cosmosDbAccount
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
        category: 'Requests'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// =========================================
// OUTPUTS
// =========================================

@description('The resource ID of the Cosmos DB account')
output cosmosDbAccountId string = cosmosDbAccount.id

@description('The name of the Cosmos DB account')
output cosmosDbAccountName string = cosmosDbAccount.name

@description('The endpoint of the Cosmos DB account')
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint

@description('The resource ID of the database')
output databaseId string = database.id

@description('The name of the database')
output databaseName string = database.name

@description('The resource ID of the private endpoint')
output privateEndpointId string = enablePrivateEndpoint ? privateEndpoint.id : ''

@description('The private IP address of the Cosmos DB account')
output privateEndpointIp string = enablePrivateEndpoint ? privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0] : ''

@description('The system-assigned managed identity principal ID')
output systemAssignedIdentityPrincipalId string = cosmosDbAccount.identity.principalId
