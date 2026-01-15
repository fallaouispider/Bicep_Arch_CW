// =========================================
// AZURE INFRASTRUCTURE - MAIN DEPLOYMENT
// =========================================
// This template deploys a complete Azure networking infrastructure including:
// - Resource Group
// - Virtual Network with address space
// - Subnet with Network Security Group
// - Baseline security rules following Azure Well-Architected Framework
// =========================================

metadata description = 'Main orchestration template for Azure networking infrastructure'
metadata version = '1.0.0'

targetScope = 'subscription'

// =========================================
// PARAMETERS
// =========================================

@description('The workload name for the resources (e.g., webapp, api, database)')
@minLength(3)
@maxLength(15)
param workloadName string

@description('The environment type for the deployment')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environmentType string

@description('Azure region for all resources. Defaults to deployment location.')
param location string = deployment().location

@description('The instance number for resource differentiation')
@minLength(3)
@maxLength(3)
param instanceNumber string = '001'

@description('Virtual Network address space in CIDR notation')
param vnetAddressPrefix string

@description('Subnet address space in CIDR notation')
param subnetAddressPrefix string

@description('Application Gateway subnet address space in CIDR notation')
param appGatewaySubnetAddressPrefix string

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable diagnostic settings for network resources')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics (required if enableDiagnostics is true)')
param logAnalyticsWorkspaceId string = ''

@description('Deploy Azure Cosmos DB NoSQL Serverless')
param deployCosmosDb bool = true

@description('Name of the Cosmos DB database')
param cosmosDbDatabaseName string = 'appdb'

@description('Array of Cosmos DB containers to create')
param cosmosDbContainers array = []

@description('Enable private endpoint for Cosmos DB')
param enableCosmosDbPrivateEndpoint bool = true

@description('Enable free tier for Cosmos DB (only one per subscription)')
param enableCosmosDbFreeTier bool = false

@description('Deploy Azure Service Bus')
param deployServiceBus bool = true

@description('Service Bus SKU tier')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param serviceBusSku string = 'Standard'

@description('Array of Service Bus queues to create')
param serviceBusQueues array = []

@description('Array of Service Bus topics to create')
param serviceBusTopics array = []

@description('Enable private endpoint for Service Bus (requires Premium SKU)')
param enableServiceBusPrivateEndpoint bool = false

@description('Enable zone redundancy for Service Bus (Premium SKU only)')
param serviceBusZoneRedundant bool = false

@description('Deploy Azure SQL Server')
param deploySqlServer bool = true

@description('SQL Server administrator login username')
param sqlServerAdminLogin string = 'sqladmin'

@description('SQL Server administrator login password')
@secure()
param sqlServerAdminPassword string

@description('Array of SQL databases to create')
param sqlDatabases array = []

@description('Enable private endpoint for SQL Server')
param enableSqlServerPrivateEndpoint bool = true

@description('Enable public network access for SQL Server')
param sqlServerPublicNetworkAccess bool = false

@description('Microsoft Entra admin object ID for SQL Server')
param sqlServerEntraAdminObjectId string = ''

@description('Microsoft Entra admin login name for SQL Server')
param sqlServerEntraAdminLogin string = ''

@description('Deploy Application Gateway')
param deployAppGateway bool = true

@description('Application Gateway SKU name')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param appGatewaySku string = 'Standard_v2'

@description('Minimum capacity units for Application Gateway autoscaling')
@minValue(0)
@maxValue(125)
param appGatewayMinCapacity int = 0

@description('Maximum capacity units for Application Gateway autoscaling')
@minValue(2)
@maxValue(125)
param appGatewayMaxCapacity int = 10

@description('Enable Web Application Firewall')
param enableWaf bool = false

@description('Deploy Azure Kubernetes Service')
param deployAKS bool = true

@description('Kubernetes version')
param kubernetesVersion string = '1.29.0'

@description('AKS node pool VM size')
param aksNodeVmSize string = 'Standard_D2s_v3'

@description('AKS node count')
@minValue(1)
@maxValue(100)
param aksNodeCount int = 3

@description('Enable AKS auto-scaling')
param enableAksAutoScaling bool = true

@description('AKS minimum node count for auto-scaling')
@minValue(1)
@maxValue(100)
param aksMinNodeCount int = 1

@description('AKS maximum node count for auto-scaling')
@minValue(1)
@maxValue(1000)
param aksMaxNodeCount int = 5

@description('AKS service CIDR')
param aksServiceCidr string = '10.2.0.0/16'

@description('AKS DNS service IP')
param aksDnsServiceIP string = '10.2.0.10'

@description('Enable AGIC addon for AKS')
param enableAGIC bool = true

@description('Enable Azure Monitor for AKS')
param enableAksMonitoring bool = true

@description('AKS SKU tier')
@allowed([
  'Free'
  'Standard'
  'Premium'
])
param aksSku string = 'Free'

@description('Deploy API Management')
param deployApiManagement bool = true

@description('API Management SKU')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param apimSku string = 'Developer'

@description('API Management SKU capacity')
@minValue(0)
@maxValue(12)
param apimCapacity int = 1

@description('API Management publisher email')
param apimPublisherEmail string = 'admin@contoso.com'

@description('API Management publisher name')
param apimPublisherName string = 'Contoso'

@description('API Management VNet type')
@allowed([
  'None'
  'External'
  'Internal'
])
param apimVirtualNetworkType string = 'External'

// =========================================
// VARIABLES
// =========================================

var locationShort = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  centralus: 'cus'
  northeurope: 'neu'
  westeurope: 'weu'
  uksouth: 'uks'
  ukwest: 'ukw'
}[location]

// Resource naming following Azure naming conventions
var resourceGroupName = 'rg-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var vnetName = 'vnet-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var subnetName = 'snet-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var appGatewaySubnetName = 'snet-appgw-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var nsgName = 'nsg-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var cosmosDbAccountName = 'cosmos-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var serviceBusNamespaceName = 'sb-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var sqlServerName = 'sql-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var appGatewayName = 'appgw-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var appGatewayPublicIpName = 'pip-appgw-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var aksClusterName = 'aks-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var aksDnsPrefix = '${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'
var apimName = 'apim-${workloadName}-${environmentType}-${locationShort}-${instanceNumber}'

// Merge default tags with user-provided tags
var defaultTags = {
  Environment: environmentType
  ManagedBy: 'Bicep'
  DeploymentDate: utcNow('yyyy-MM-dd')
  Location: location
}

var allTags = union(defaultTags, tags)

// =========================================
// RESOURCES
// =========================================

@description('Create Resource Group for all networking resources')
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: allTags
}

// =========================================
// MODULES
// =========================================

@description('Deploy Virtual Network with Subnet and NSG')
module networkModule 'modules/networking/vnet.bicep' = {
  name: 'networkDeployment-${uniqueString(resourceGroup.id)}'
  scope: resourceGroup
  params: {
    vnetName: vnetName
    location: location
    vnetAddressPrefix: vnetAddressPrefix
    subnetName: subnetName
    subnetAddressPrefix: subnetAddressPrefix
    appGatewaySubnetName: appGatewaySubnetName
    appGatewaySubnetAddressPrefix: appGatewaySubnetAddressPrefix
    nsgName: nsgName
    tags: allTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

@description('Deploy Azure Cosmos DB with NoSQL API and Serverless capacity')
module cosmosDbModule 'modules/database/cosmosdb.bicep' = if (deployCosmosDb) {
  name: 'cosmosDbDeployment-${uniqueString(resourceGroup.id)}'
  scope: resourceGroup
  dependsOn: [
    networkModule
  ]
  params: {
    cosmosDbAccountName: cosmosDbAccountName
    location: location
    databaseName: cosmosDbDatabaseName
    containers: cosmosDbContainers
    subnetId: networkModule.outputs.subnetId
    enablePrivateEndpoint: enableCosmosDbPrivateEndpoint
    tags: allTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    enableFreeTier: enableCosmosDbFreeTier
  }
}

@description('Deploy Azure Service Bus namespace with queues and topics')
module serviceBusModule 'modules/messaging/servicebus.bicep' = if (deployServiceBus) {
  name: 'serviceBusDeployment-${uniqueString(resourceGroup.id)}'
  scope: resourceGroup
  dependsOn: [
    networkModule
  ]
  params: {
    serviceBusNamespaceName: serviceBusNamespaceName
    location: location
    skuName: serviceBusSku
    queues: serviceBusQueues
    topics: serviceBusTopics
    subnetId: networkModule.outputs.subnetId
    enablePrivateEndpoint: enableServiceBusPrivateEndpoint
    zoneRedundant: serviceBusZoneRedundant
    tags: allTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

@description('Deploy Azure SQL Server with databases')
module sqlServerModule 'modules/database/sqlserver.bicep' = if (deploySqlServer) {
  name: 'sqlServerDeployment-${uniqueString(resourceGroup.id)}'
  scope: resourceGroup
  dependsOn: [
    networkModule
  ]
  params: {
    sqlServerName: sqlServerName
    location: location
    administratorLogin: sqlServerAdminLogin
    administratorLoginPassword: sqlServerAdminPassword
    databases: sqlDatabases
    subnetId: networkModule.outputs.subnetId
    enablePrivateEndpoint: enableSqlServerPrivateEndpoint
    publicNetworkAccess: sqlServerPublicNetworkAccess
    entraAdminObjectId: sqlServerEntraAdminObjectId
    entraAdminLogin: sqlServerEntraAdminLogin
    tags: allTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

@description('Deploy Application Gateway with AGIC support')
module appGatewayModule 'modules/networking/appgateway.bicep' = if (deployAppGateway) {
  name: 'appGatewayDeployment-${uniqueString(resourceGroup.id)}'
  scope: resourceGroup
  dependsOn: [
    networkModule
  ]
  params: {
    appGatewayName: appGatewayName
    location: location
    skuName: appGatewaySku
    skuTier: appGatewaySku
    minCapacity: appGatewayMinCapacity
    maxCapacity: appGatewayMaxCapacity
    publicIpName: appGatewayPublicIpName
    subnetId: networkModule.outputs.appGatewaySubnetId
    enableWaf: enableWaf
    tags: allTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

@description('Deploy Azure Kubernetes Service with AGIC addon')
module aksModule 'modules/compute/aks.bicep' = if (deployAKS) {
  name: 'aksDeployment-${uniqueString(resourceGroup.id)}'
  scope: resourceGroup
  dependsOn: [
    networkModule
    appGatewayModule
  ]
  params: {
    aksClusterName: aksClusterName
    location: location
    dnsPrefix: aksDnsPrefix
    kubernetesVersion: kubernetesVersion
    nodeCount: aksNodeCount
    nodeVmSize: aksNodeVmSize
    subnetId: networkModule.outputs.subnetId
    enableAutoScaling: enableAksAutoScaling
    minCount: aksMinNodeCount
    maxCount: aksMaxNodeCount
    serviceCidr: aksServiceCidr
    dnsServiceIP: aksDnsServiceIP
    enableAGIC: enableAGIC && deployAppGateway
    applicationGatewayId: deployAppGateway ? appGatewayModule.outputs.appGatewayId : ''
    enableMonitoring: enableAksMonitoring
    logAnalyticsWorkspaceId: enableAksMonitoring ? logAnalyticsWorkspaceId : ''
    skuTier: aksSku
    tags: allTags
    enableDiagnostics: enableDiagnostics
    diagnosticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

@description('Deploy API Management with VNet integration')
module apimModule 'modules/integration/apim.bicep' = if (deployApiManagement) {
  name: 'apimDeployment-${uniqueString(resourceGroup.id)}'
  scope: resourceGroup
  dependsOn: [
    networkModule
  ]
  params: {
    apimName: apimName
    location: location
    skuName: apimSku
    skuCapacity: apimCapacity
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkType: apimVirtualNetworkType
    subnetId: networkModule.outputs.subnetId
    tags: allTags
    enableDiagnostics: enableDiagnostics
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// =========================================
// OUTPUTS
// =========================================

@description('The resource ID of the Resource Group')
output resourceGroupId string = resourceGroup.id

@description('The name of the Resource Group')
output resourceGroupName string = resourceGroup.name

@description('The resource ID of the Virtual Network')
output vnetId string = networkModule.outputs.vnetId

@description('The name of the Virtual Network')
output vnetName string = networkModule.outputs.vnetName

@description('The address prefix of the Virtual Network')
output vnetAddressPrefix string = networkModule.outputs.vnetAddressPrefix

@description('The resource ID of the Subnet')
output subnetId string = networkModule.outputs.subnetId

@description('The name of the Subnet')
output subnetName string = networkModule.outputs.subnetName

@description('The resource ID of the Network Security Group')
output nsgId string = networkModule.outputs.nsgId

@description('The name of the Network Security Group')
output nsgName string = networkModule.outputs.nsgName

@description('The resource ID of the Cosmos DB account')
output cosmosDbAccountId string = deployCosmosDb ? cosmosDbModule.outputs.cosmosDbAccountId : ''

@description('The name of the Cosmos DB account')
output cosmosDbAccountName string = deployCosmosDb ? cosmosDbModule.outputs.cosmosDbAccountName : ''

@description('The endpoint of the Cosmos DB account')
output cosmosDbEndpoint string = deployCosmosDb ? cosmosDbModule.outputs.cosmosDbEndpoint : ''

@description('The resource ID of the Cosmos DB database')
output cosmosDbDatabaseId string = deployCosmosDb ? cosmosDbModule.outputs.databaseId : ''

@description('The name of the Cosmos DB database')
output cosmosDbDatabaseName string = deployCosmosDb ? cosmosDbModule.outputs.databaseName : ''

@description('The resource ID of the Service Bus namespace')
output serviceBusNamespaceId string = deployServiceBus ? serviceBusModule.outputs.serviceBusNamespaceId : ''

@description('The name of the Service Bus namespace')
output serviceBusNamespaceName string = deployServiceBus ? serviceBusModule.outputs.serviceBusNamespaceName : ''

@description('The endpoint of the Service Bus namespace')
output serviceBusEndpoint string = deployServiceBus ? serviceBusModule.outputs.serviceBusEndpoint : ''

@description('Array of Service Bus queue names')
output serviceBusQueueNames array = deployServiceBus ? serviceBusModule.outputs.queueNames : []

@description('Array of Service Bus topic names')
output serviceBusTopicNames array = deployServiceBus ? serviceBusModule.outputs.topicNames : []

@description('The resource ID of the SQL Server')
output sqlServerId string = deploySqlServer ? sqlServerModule.outputs.sqlServerId : ''

@description('The name of the SQL Server')
output sqlServerName string = deploySqlServer ? sqlServerModule.outputs.sqlServerName : ''

@description('The fully qualified domain name of the SQL Server')
output sqlServerFqdn string = deploySqlServer ? sqlServerModule.outputs.sqlServerFqdn : ''

@description('Array of SQL database names')
output sqlDatabaseNames array = deploySqlServer ? sqlServerModule.outputs.databaseNames : []

@description('Array of SQL database resource IDs')
output sqlDatabaseIds array = deploySqlServer ? sqlServerModule.outputs.databaseIds : []

@description('The resource ID of the Application Gateway')
output appGatewayId string = deployAppGateway ? appGatewayModule.outputs.appGatewayId : ''

@description('The name of the Application Gateway')
output appGatewayName string = deployAppGateway ? appGatewayModule.outputs.appGatewayName : ''

@description('The public IP address of the Application Gateway')
output appGatewayPublicIp string = deployAppGateway ? appGatewayModule.outputs.publicIpAddress : ''

@description('The FQDN of the Application Gateway')
output appGatewayFqdn string = deployAppGateway ? appGatewayModule.outputs.fqdn : ''

@description('The resource ID of the Application Gateway managed identity')
output appGatewayIdentityId string = deployAppGateway ? appGatewayModule.outputs.identityId : ''

@description('The resource ID of the AKS cluster')
output aksClusterId string = deployAKS ? aksModule.outputs.aksClusterId : ''

@description('The name of the AKS cluster')
output aksClusterName string = deployAKS ? aksModule.outputs.aksClusterName : ''

@description('The FQDN of the AKS cluster')
output aksClusterFqdn string = deployAKS ? aksModule.outputs.aksClusterFqdn : ''

@description('The Kubernetes version')
output kubernetesVersion string = deployAKS ? aksModule.outputs.kubernetesVersion : ''

@description('The principal ID of the AKS cluster managed identity')
output aksIdentityPrincipalId string = deployAKS ? aksModule.outputs.identityPrincipalId : ''

@description('The node resource group name')
output aksNodeResourceGroup string = deployAKS ? aksModule.outputs.nodeResourceGroup : ''

@description('The AGIC addon identity object ID')
output agicIdentityObjectId string = deployAKS ? aksModule.outputs.agicIdentityObjectId : ''

@description('The AGIC addon identity client ID')
output agicIdentityClientId string = deployAKS ? aksModule.outputs.agicIdentityClientId : ''

@description('The resource ID of the API Management service')
output apimId string = deployApiManagement ? apimModule.outputs.apimId : ''

@description('The name of the API Management service')
output apimName string = deployApiManagement ? apimModule.outputs.apimName : ''

@description('The gateway URL of the API Management service')
output apimGatewayUrl string = deployApiManagement ? apimModule.outputs.gatewayUrl : ''

@description('The developer portal URL')
output apimDeveloperPortalUrl string = deployApiManagement ? apimModule.outputs.developerPortalUrl : ''

@description('The management API URL')
output apimManagementApiUrl string = deployApiManagement ? apimModule.outputs.managementApiUrl : ''

@description('The portal URL')
output apimPortalUrl string = deployApiManagement ? apimModule.outputs.portalUrl : ''

@description('The principal ID of the API Management managed identity')
output apimIdentityPrincipalId string = deployApiManagement ? apimModule.outputs.identityPrincipalId : ''

@description('The public IP addresses of API Management')
output apimPublicIpAddresses array = deployApiManagement ? apimModule.outputs.publicIpAddresses : []

@description('The private IP addresses of API Management')
output apimPrivateIpAddresses array = deployApiManagement ? apimModule.outputs.privateIpAddresses : []
