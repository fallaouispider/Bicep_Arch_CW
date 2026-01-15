// =========================================
// SERVICE BUS MODULE
// =========================================
// This module creates:
// - Azure Service Bus namespace (Standard Tier)
// - Queues with configurable settings
// - Topics with subscriptions
// - Private endpoint for secure VNet integration
// - Following Azure best practices and Well-Architected Framework
// =========================================

metadata description = 'Deploys Azure Service Bus Standard Tier namespace with queues, topics, and private endpoint'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the Service Bus namespace')
@minLength(6)
@maxLength(50)
param serviceBusNamespaceName string

@description('Azure region for the Service Bus namespace')
param location string = resourceGroup().location

@description('Service Bus SKU')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('Array of queues to create')
param queues array = []

@description('Array of topics to create')
param topics array = []

@description('Subnet resource ID for private endpoint')
param subnetId string

@description('Enable private endpoint for Service Bus (requires Premium SKU)')
param enablePrivateEndpoint bool = false

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable diagnostic settings')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Disable local authentication (SAS keys)')
param disableLocalAuth bool = false

@description('Enable zone redundancy (Premium SKU only)')
param zoneRedundant bool = false

@description('Minimum TLS version')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimumTlsVersion string = '1.2'

// =========================================
// RESOURCES
// =========================================

@description('Azure Service Bus Namespace')
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    zoneRedundant: zoneRedundant
    minimumTlsVersion: minimumTlsVersion
  }
}

@description('Service Bus Queues')
resource serviceBusQueues 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = [for queue in queues: {
  name: queue.name
  parent: serviceBusNamespace
  properties: {
    lockDuration: contains(queue, 'lockDuration') ? queue.lockDuration : 'PT1M'
    maxSizeInMegabytes: contains(queue, 'maxSizeInMegabytes') ? queue.maxSizeInMegabytes : 1024
    requiresDuplicateDetection: contains(queue, 'requiresDuplicateDetection') ? queue.requiresDuplicateDetection : false
    requiresSession: contains(queue, 'requiresSession') ? queue.requiresSession : false
    defaultMessageTimeToLive: contains(queue, 'defaultMessageTimeToLive') ? queue.defaultMessageTimeToLive : 'P14D'
    deadLetteringOnMessageExpiration: contains(queue, 'deadLetteringOnMessageExpiration') ? queue.deadLetteringOnMessageExpiration : true
    duplicateDetectionHistoryTimeWindow: contains(queue, 'duplicateDetectionHistoryTimeWindow') ? queue.duplicateDetectionHistoryTimeWindow : 'PT10M'
    maxDeliveryCount: contains(queue, 'maxDeliveryCount') ? queue.maxDeliveryCount : 10
    enableBatchedOperations: contains(queue, 'enableBatchedOperations') ? queue.enableBatchedOperations : true
    autoDeleteOnIdle: contains(queue, 'autoDeleteOnIdle') ? queue.autoDeleteOnIdle : 'P10675199DT2H48M5.4775807S'
    enablePartitioning: contains(queue, 'enablePartitioning') ? queue.enablePartitioning : false
    enableExpress: contains(queue, 'enableExpress') ? queue.enableExpress : false
  }
}]

@description('Service Bus Topics')
resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = [for topic in topics: {
  name: topic.name
  parent: serviceBusNamespace
  properties: {
    maxSizeInMegabytes: contains(topic, 'maxSizeInMegabytes') ? topic.maxSizeInMegabytes : 1024
    requiresDuplicateDetection: contains(topic, 'requiresDuplicateDetection') ? topic.requiresDuplicateDetection : false
    defaultMessageTimeToLive: contains(topic, 'defaultMessageTimeToLive') ? topic.defaultMessageTimeToLive : 'P14D'
    duplicateDetectionHistoryTimeWindow: contains(topic, 'duplicateDetectionHistoryTimeWindow') ? topic.duplicateDetectionHistoryTimeWindow : 'PT10M'
    enableBatchedOperations: contains(topic, 'enableBatchedOperations') ? topic.enableBatchedOperations : true
    autoDeleteOnIdle: contains(topic, 'autoDeleteOnIdle') ? topic.autoDeleteOnIdle : 'P10675199DT2H48M5.4775807S'
    enablePartitioning: contains(topic, 'enablePartitioning') ? topic.enablePartitioning : false
    enableExpress: contains(topic, 'enableExpress') ? topic.enableExpress : false
    supportOrdering: contains(topic, 'supportOrdering') ? topic.supportOrdering : true
  }
}]

@description('Service Bus Topic Subscriptions')
resource serviceBusSubscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = [for (topic, topicIndex) in topics: if (contains(topic, 'subscriptions')) {
  name: topic.subscriptions[0].name
  parent: serviceBusTopics[topicIndex]
  properties: {
    lockDuration: contains(topic.subscriptions[0], 'lockDuration') ? topic.subscriptions[0].lockDuration : 'PT1M'
    requiresSession: contains(topic.subscriptions[0], 'requiresSession') ? topic.subscriptions[0].requiresSession : false
    defaultMessageTimeToLive: contains(topic.subscriptions[0], 'defaultMessageTimeToLive') ? topic.subscriptions[0].defaultMessageTimeToLive : 'P14D'
    deadLetteringOnMessageExpiration: contains(topic.subscriptions[0], 'deadLetteringOnMessageExpiration') ? topic.subscriptions[0].deadLetteringOnMessageExpiration : true
    maxDeliveryCount: contains(topic.subscriptions[0], 'maxDeliveryCount') ? topic.subscriptions[0].maxDeliveryCount : 10
    enableBatchedOperations: contains(topic.subscriptions[0], 'enableBatchedOperations') ? topic.subscriptions[0].enableBatchedOperations : true
    autoDeleteOnIdle: contains(topic.subscriptions[0], 'autoDeleteOnIdle') ? topic.subscriptions[0].autoDeleteOnIdle : 'P10675199DT2H48M5.4775807S'
  }
}]

@description('Private Endpoint for Service Bus')
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (enablePrivateEndpoint) {
  name: '${serviceBusNamespaceName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${serviceBusNamespaceName}-plsc'
        properties: {
          privateLinkServiceId: serviceBusNamespace.id
          groupIds: [
            'namespace'
          ]
        }
      }
    ]
  }
}

@description('Diagnostic settings for Service Bus namespace')
resource serviceBusDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${serviceBusNamespaceName}-diagnostics'
  scope: serviceBusNamespace
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

// =========================================
// OUTPUTS
// =========================================

@description('The resource ID of the Service Bus namespace')
output serviceBusNamespaceId string = serviceBusNamespace.id

@description('The name of the Service Bus namespace')
output serviceBusNamespaceName string = serviceBusNamespace.name

@description('The endpoint of the Service Bus namespace')
output serviceBusEndpoint string = serviceBusNamespace.properties.serviceBusEndpoint

@description('The resource ID of the private endpoint')
output privateEndpointId string = enablePrivateEndpoint ? privateEndpoint.id : ''

@description('The system-assigned managed identity principal ID')
output systemAssignedIdentityPrincipalId string = serviceBusNamespace.identity.principalId

@description('Array of queue names')
output queueNames array = [for (queue, i) in queues: serviceBusQueues[i].name]

@description('Array of topic names')
output topicNames array = [for (topic, i) in topics: serviceBusTopics[i].name]
