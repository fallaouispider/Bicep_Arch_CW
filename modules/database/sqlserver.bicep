// =========================================
// SQL SERVER MODULE
// =========================================
// This module creates:
// - Azure SQL Server (logical server)
// - SQL Databases with General Purpose Gen5 tier
// - Private endpoint for secure VNet integration
// - Firewall rules and security configurations
// - Following Azure best practices and Well-Architected Framework
// =========================================

metadata description = 'Deploys Azure SQL Server with databases and private endpoint'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the SQL Server')
@minLength(1)
@maxLength(63)
param sqlServerName string

@description('Azure region for the SQL Server')
param location string = resourceGroup().location

@description('SQL Server administrator login username')
@minLength(1)
param administratorLogin string

@description('SQL Server administrator login password')
@secure()
@minLength(8)
@maxLength(128)
param administratorLoginPassword string

@description('Array of databases to create')
param databases array = []

@description('Subnet resource ID for private endpoint')
param subnetId string

@description('Enable private endpoint for SQL Server')
param enablePrivateEndpoint bool = true

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable diagnostic settings')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Enable Microsoft Entra-only authentication')
param entraOnlyAuthentication bool = false

@description('Microsoft Entra admin object ID')
param entraAdminObjectId string = ''

@description('Microsoft Entra admin login name')
param entraAdminLogin string = ''

@description('Minimum TLS version')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimalTlsVersion string = '1.2'

@description('Enable public network access')
param publicNetworkAccess bool = false

// =========================================
// RESOURCES
// =========================================

@description('Azure SQL Server')
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    minimalTlsVersion: minimalTlsVersion
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

@description('Microsoft Entra admin configuration')
resource sqlServerEntraAdmin 'Microsoft.Sql/servers/administrators@2023-05-01-preview' = if (!empty(entraAdminObjectId) && !empty(entraAdminLogin)) {
  name: 'ActiveDirectory'
  parent: sqlServer
  properties: {
    administratorType: 'ActiveDirectory'
    login: entraAdminLogin
    sid: entraAdminObjectId
    tenantId: subscription().tenantId
  }
}

@description('Allow Azure services to access server')
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = if (!enablePrivateEndpoint) {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('SQL Databases')
resource sqlDatabases 'Microsoft.Sql/servers/databases@2023-05-01-preview' = [for database in databases: {
  name: database.name
  parent: sqlServer
  location: location
  tags: tags
  sku: {
    name: contains(database, 'skuName') ? database.skuName : 'GP_Gen5_2'
    tier: contains(database, 'tier') ? database.tier : 'GeneralPurpose'
    family: contains(database, 'family') ? database.family : 'Gen5'
    capacity: contains(database, 'vCores') ? database.vCores : 2
  }
  properties: {
    collation: contains(database, 'collation') ? database.collation : 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: contains(database, 'maxSizeBytes') ? database.maxSizeBytes : 34359738368 // 32 GB
    catalogCollation: contains(database, 'catalogCollation') ? database.catalogCollation : 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: contains(database, 'zoneRedundant') ? database.zoneRedundant : false
    licenseType: contains(database, 'licenseType') ? database.licenseType : 'LicenseIncluded'
    readScale: contains(database, 'readScale') ? database.readScale : 'Disabled'
    requestedBackupStorageRedundancy: contains(database, 'backupStorageRedundancy') ? database.backupStorageRedundancy : 'Local'
    minCapacity: contains(database, 'minCapacity') ? database.minCapacity : json('null')
    autoPauseDelay: contains(database, 'autoPauseDelay') ? database.autoPauseDelay : json('null')
  }
}]

@description('Transparent Data Encryption for databases')
resource sqlDatabaseTDE 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-05-01-preview' = [for (database, i) in databases: {
  name: 'current'
  parent: sqlDatabases[i]
  properties: {
    state: 'Enabled'
  }
}]

@description('Short-term backup retention policy for databases')
resource sqlDatabaseBackupShortTermRetention 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2023-05-01-preview' = [for (database, i) in databases: {
  name: 'default'
  parent: sqlDatabases[i]
  properties: {
    retentionDays: contains(database, 'backupRetentionDays') ? database.backupRetentionDays : 7
    diffBackupIntervalInHours: 24
  }
}]

@description('Private Endpoint for SQL Server')
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (enablePrivateEndpoint) {
  name: '${sqlServerName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServerName}-plsc'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

@description('Diagnostic settings for SQL Server')
resource sqlServerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${sqlServerName}-diagnostics'
  scope: sqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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

@description('Diagnostic settings for SQL Databases')
resource sqlDatabaseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (database, i) in databases: if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${database.name}-diagnostics'
  scope: sqlDatabases[i]
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
}]

// =========================================
// OUTPUTS
// =========================================

@description('The resource ID of the SQL Server')
output sqlServerId string = sqlServer.id

@description('The name of the SQL Server')
output sqlServerName string = sqlServer.name

@description('The fully qualified domain name of the SQL Server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('The resource ID of the private endpoint')
output privateEndpointId string = enablePrivateEndpoint ? privateEndpoint.id : ''

@description('The system-assigned managed identity principal ID')
output systemAssignedIdentityPrincipalId string = sqlServer.identity.principalId

@description('Array of database names')
output databaseNames array = [for (database, i) in databases: sqlDatabases[i].name]

@description('Array of database resource IDs')
output databaseIds array = [for (database, i) in databases: sqlDatabases[i].id]
