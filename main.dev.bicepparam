// =========================================
// DEVELOPMENT ENVIRONMENT PARAMETERS
// =========================================
// Parameter file for development environment deployment
// Uses 10.1.x.x address space to avoid conflicts with production
// =========================================

using './main.bicep'

// =========================================
// WORKLOAD CONFIGURATION
// =========================================

param workloadName = 'webapp'
param environmentType = 'dev'
param location = 'eastus2'
param instanceNumber = '001'

// =========================================
// NETWORKING CONFIGURATION
// =========================================

// Development VNet uses 10.1.0.0/16 address space
param vnetAddressPrefix = '10.1.0.0/16'

// Subnet for development workload
param subnetAddressPrefix = '10.1.0.0/24'

// Application Gateway subnet
param appGatewaySubnetAddressPrefix = '10.1.1.0/24'

// =========================================
// DIAGNOSTICS CONFIGURATION
// =========================================

param enableDiagnostics = false
param logAnalyticsWorkspaceId = ''

// =========================================
// COSMOS DB CONFIGURATION
// =========================================

param deployCosmosDb = true
param cosmosDbDatabaseName = 'appdb-dev'
param enableCosmosDbPrivateEndpoint = true
param enableCosmosDbFreeTier = false

// Example containers configuration (uncomment and modify as needed)
param cosmosDbContainers = [
  {
    name: 'products'
    partitionKeyPaths: [
      '/category'
    ]
    partitionKeyKind: 'Hash'
    partitionKeyVersion: 2
  }
  {
    name: 'users'
    partitionKeyPaths: [
      '/userId'
    ]
    partitionKeyKind: 'Hash'
    partitionKeyVersion: 2
  }
]

// =========================================
// SERVICE BUS CONFIGURATION
// =========================================

param deployServiceBus = true
param serviceBusSku = 'Standard'
param enableServiceBusPrivateEndpoint = false
param serviceBusZoneRedundant = false

// Example queues configuration
param serviceBusQueues = [
  {
    name: 'orders'
    maxSizeInMegabytes: 1024
    maxDeliveryCount: 10
    lockDuration: 'PT1M'
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
  }
  {
    name: 'notifications'
    maxSizeInMegabytes: 1024
    maxDeliveryCount: 5
    lockDuration: 'PT30S'
  }
]

// Example topics configuration
param serviceBusTopics = [
  {
    name: 'events'
    maxSizeInMegabytes: 1024
    subscriptions: [
      {
        name: 'all-events'
        maxDeliveryCount: 10
        lockDuration: 'PT1M'
      }
    ]
  }
]

// =========================================
// SQL SERVER CONFIGURATION
// =========================================

param deploySqlServer = true
param sqlServerAdminLogin = 'sqladmin'
// IMPORTANT: Set password via command line: --parameters sqlServerAdminPassword='YourSecurePassword123!'
param sqlServerAdminPassword = '' // Must be provided at deployment time
param enableSqlServerPrivateEndpoint = true
param sqlServerPublicNetworkAccess = false
param sqlServerEntraAdminObjectId = ''
param sqlServerEntraAdminLogin = ''

// SQL Databases configuration - General Purpose Gen5, 2 vCores
param sqlDatabases = [
  {
    name: 'CWDB'
    skuName: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 34359738368 // 32 GB
    backupRetentionDays: 7
    zoneRedundant: false
  }
  {
    name: 'CW-Utility'
    skuName: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 34359738368 // 32 GB
    backupRetentionDays: 7
    zoneRedundant: false
  }
  {
    name: 'sql01-nonprd-emea-db'
    skuName: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 34359738368 // 32 GB
    backupRetentionDays: 7
    zoneRedundant: false
  }
]

// =========================================
// APPLICATION GATEWAY CONFIGURATION
// =========================================

param deployAppGateway = true
param appGatewaySku = 'Standard_v2'
param appGatewayMinCapacity = 0
param appGatewayMaxCapacity = 2
param enableWaf = false

// =========================================
// AZURE KUBERNETES SERVICE CONFIGURATION
// =========================================

param deployAKS = true
param kubernetesVersion = '1.32'
param aksNodeVmSize = 'Standard_D2s_v3'
param aksNodeCount = 2
param enableAksAutoScaling = true
param aksMinNodeCount = 1
param aksMaxNodeCount = 3
param aksServiceCidr = '10.2.0.0/16'
param aksDnsServiceIP = '10.2.0.10'
param enableAGIC = true
param enableAksMonitoring = false
param aksSku = 'Free'

// =========================================
// API MANAGEMENT CONFIGURATION
// =========================================

param deployApiManagement = true
param apimSku = 'Developer'
param apimCapacity = 1
param apimPublisherEmail = 'dev-team@contoso.com'
param apimPublisherName = 'Contoso Dev'
param apimVirtualNetworkType = 'External'

// =========================================
// RESOURCE TAGGING
// =========================================

param tags = {
  Application: 'WebApplication'
  CostCenter: 'IT-Development'
  Owner: 'dev-team@company.com'
  Criticality: 'Low'
  DataClassification: 'Internal'
  BusinessUnit: 'Engineering'
}
