// =========================================
// PRODUCTION ENVIRONMENT PARAMETERS
// =========================================
// Parameter file for production environment deployment
// Uses 10.0.x.x address space with reserved capacity for growth
// =========================================

using './main.bicep'

// =========================================
// WORKLOAD CONFIGURATION
// =========================================

param workloadName = 'webapp'
param environmentType = 'prod'
param location = 'eastus2'
param instanceNumber = '001'

// =========================================
// NETWORKING CONFIGURATION
// =========================================

// Production VNet uses 10.0.0.0/16 address space
param vnetAddressPrefix = '10.0.0.0/16'

// Subnet for production workload - leaves room for additional subnets
param subnetAddressPrefix = '10.0.0.0/24'

// =========================================
// DIAGNOSTICS CONFIGURATION
// =========================================

param enableDiagnostics = true
// IMPORTANT: Update this with your Log Analytics Workspace resource ID before deployment
param logAnalyticsWorkspaceId = '/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name>'

// =========================================
// COSMOS DB CONFIGURATION
// =========================================

param deployCosmosDb = true
param cosmosDbDatabaseName = 'appdb-prod'
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
  {
    name: 'orders'
    partitionKeyPaths: [
      '/customerId'
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

// Production queues configuration
param serviceBusQueues = [
  {
    name: 'orders'
    maxSizeInMegabytes: 2048
    maxDeliveryCount: 10
    lockDuration: 'PT1M'
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    enableBatchedOperations: true
  }
  {
    name: 'notifications'
    maxSizeInMegabytes: 1024
    maxDeliveryCount: 5
    lockDuration: 'PT30S'
    deadLetteringOnMessageExpiration: true
  }
  {
    name: 'payments'
    maxSizeInMegabytes: 2048
    maxDeliveryCount: 3
    lockDuration: 'PT2M'
    requiresDuplicateDetection: true
  }
]

// Production topics configuration
param serviceBusTopics = [
  {
    name: 'events'
    maxSizeInMegabytes: 2048
    supportOrdering: true
    subscriptions: [
      {
        name: 'all-events'
        maxDeliveryCount: 10
        lockDuration: 'PT1M'
        deadLetteringOnMessageExpiration: true
      }
    ]
  }
  {
    name: 'audit'
    maxSizeInMegabytes: 2048
    requiresDuplicateDetection: true
    subscriptions: [
      {
        name: 'audit-processor'
        maxDeliveryCount: 3
        lockDuration: 'PT5M'
      }
    ]
  }
]

// =========================================
// SQL SERVER CONFIGURATION
// =========================================

param deploySqlServer = true
param sqlServerAdminLogin = 'sqladmin'
// IMPORTANT: Set password via command line or Azure Key Vault: --parameters sqlServerAdminPassword='YourSecurePassword123!'
param sqlServerAdminPassword = '' // Must be provided at deployment time
param enableSqlServerPrivateEndpoint = true
param sqlServerPublicNetworkAccess = false
// IMPORTANT: Configure Microsoft Entra admin for production
param sqlServerEntraAdminObjectId = '' // Set your Entra admin object ID
param sqlServerEntraAdminLogin = '' // Set your Entra admin login name

// Production SQL Databases configuration - General Purpose Gen5, 2 vCores
param sqlDatabases = [
  {
    name: 'CWDB'
    skuName: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 107374182400 // 100 GB
    backupRetentionDays: 35 // 5 weeks
    backupStorageRedundancy: 'Geo'
    zoneRedundant: false
    licenseType: 'LicenseIncluded'
  }
  {
    name: 'CW-Utility'
    skuName: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 53687091200 // 50 GB
    backupRetentionDays: 35
    backupStorageRedundancy: 'Geo'
    zoneRedundant: false
    licenseType: 'LicenseIncluded'
  }
  {
    name: 'sql01-nonprd-emea-db'
    skuName: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 107374182400 // 100 GB
    backupRetentionDays: 35
    backupStorageRedundancy: 'Geo'
    zoneRedundant: false
    licenseType: 'LicenseIncluded'
  }
]

// =========================================
// APPLICATION GATEWAY CONFIGURATION
// =========================================

param deployAppGateway = true
param appGatewaySku = 'WAF_v2'
param appGatewayMinCapacity = 2
param appGatewayMaxCapacity = 10
param enableWaf = true

// =========================================
// AZURE KUBERNETES SERVICE CONFIGURATION
// =========================================

param deployAKS = true
param kubernetesVersion = '1.29.0'
param aksNodeVmSize = 'Standard_D4s_v3'
param aksNodeCount = 3
param enableAksAutoScaling = true
param aksMinNodeCount = 3
param aksMaxNodeCount = 10
param aksServiceCidr = '10.2.0.0/16'
param aksDnsServiceIP = '10.2.0.10'
param enableAGIC = true
param enableAksMonitoring = true
param aksSku = 'Standard'

// =========================================
// API MANAGEMENT CONFIGURATION
// =========================================

param deployApiManagement = true
param apimSku = 'Developer'  // Use Standard or Premium for production
param apimCapacity = 1
param apimPublisherEmail = 'ops-team@contoso.com'
param apimPublisherName = 'Contoso'
param apimVirtualNetworkType = 'External'

// =========================================
// AZURE CONTAINER REGISTRY CONFIGURATION
// =========================================

param deployACR = true
param acrSku = 'Premium'  // Use Premium for production with private endpoint support
param enableAcrAdminUser = false
param enableAcrPrivateEndpoint = true
param acrPublicNetworkAccess = false
param acrRetentionDays = 30
param enableAcrZoneRedundancy = true

// =========================================
// DEVOPS RUNNER VM CONFIGURATION
// =========================================

param deployDevOpsVM = true
param devOpsVmSize = 'Standard_D4s_v3'
param devOpsVmOsType = 'Linux'
param devOpsVmAdminUsername = 'azureuser'
// IMPORTANT: Set password via command line: --parameters devOpsVmAdminPassword='YourSecurePassword123!'
param devOpsVmAdminPassword = '' // Must be provided at deployment time
param devOpsVmSshPublicKey = '' // Optional: Set SSH public key for Linux VM
param enableDevOpsVmPublicIp = false
param devOpsVmOsDiskSizeGB = 256
param enableDevOpsVmDataDisk = true
param devOpsVmDataDiskSizeGB = 512
// IMPORTANT: Configure Azure DevOps settings if you want to auto-register the agent
param devOpsOrgUrl = '' // e.g., https://dev.azure.com/yourorg
param devOpsPat = '' // Azure DevOps Personal Access Token
param devOpsPoolName = 'Production'

// =========================================
// RESOURCE TAGGING
// =========================================

param tags = {
  Application: 'WebApplication'
  CostCenter: 'IT-Production'
  Owner: 'ops-team@company.com'
  Criticality: 'High'
  DataClassification: 'Confidential'
  BusinessUnit: 'Engineering'
  SLA: '99.9'
  BackupPolicy: 'Daily'
}
