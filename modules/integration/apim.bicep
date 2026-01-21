// =========================================
// API MANAGEMENT MODULE
// =========================================
// This module creates:
// - API Management instance (Developer Tier)
// - Virtual Network integration (Internal or External)
// - System-assigned managed identity
// - Default products, APIs, and subscriptions
// Following Azure API Management best practices
// =========================================

metadata description = 'Deploys Azure API Management with VNet integration'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the API Management service')
@minLength(1)
@maxLength(50)
param apimName string

@description('Azure region for the API Management service')
param location string = resourceGroup().location

@description('SKU name for API Management')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Developer'

@description('SKU capacity (number of units)')
@minValue(0)
@maxValue(12)
param skuCapacity int = 1

@description('Publisher email address')
@minLength(1)
param publisherEmail string

@description('Publisher organization name')
@minLength(1)
param publisherName string

@description('Virtual Network type')
@allowed([
  'None'
  'External'
  'Internal'
])
param virtualNetworkType string = 'External'

@description('Resource ID of the subnet for API Management')
param subnetId string = ''

@description('Enable zones for zone redundancy (Premium SKU only)')
param enableZones bool = false

@description('Availability zones (Premium SKU only)')
param zones array = []

@description('Enable system-assigned managed identity')
param enableSystemIdentity bool = true

@description('Enable client certificate for backend')
param enableClientCertificate bool = false

@description('Custom domain configurations')
param customDomains array = []

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable diagnostic settings')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Minimum API version. Use empty string for no restriction or date format yyyy-mm-dd')
param minApiVersion string = ''

@description('Enable developer portal')
param enableDeveloperPortal bool = true

@description('Public IP address IDs for Premium SKU')
param publicIpAddressIds array = []

// =========================================
// VARIABLES
// =========================================

var vnetConfiguration = virtualNetworkType != 'None' && !empty(subnetId) ? {
  subnetResourceId: subnetId
} : null

// =========================================
// RESOURCES
// =========================================

@description('API Management service')
resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  zones: enableZones && skuName == 'Premium' ? zones : null
  identity: enableSystemIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: virtualNetworkType
    virtualNetworkConfiguration: vnetConfiguration
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
    }
    certificates: enableClientCertificate ? [] : null
    hostnameConfigurations: !empty(customDomains) ? customDomains : null
    publicIpAddressId: !empty(publicIpAddressIds) && skuName == 'Premium' ? publicIpAddressIds[0] : null
    enableClientCertificate: skuName == 'Developer' ? null : enableClientCertificate
    disableGateway: false
    apiVersionConstraint: !empty(minApiVersion) ? {
      minApiVersion: minApiVersion
    } : {}
    publicNetworkAccess: virtualNetworkType == 'Internal' ? 'Disabled' : 'Enabled'
  }
}

@description('Default Echo API (built-in)')
resource echoApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: 'echo-api'
  parent: apiManagement
  properties: {
    displayName: 'Echo API'
    description: 'Echo API for testing'
    path: 'echo'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://echoapi.cloudapp.net/api'
    subscriptionRequired: true
    isCurrent: true
  }
}

@description('Starter product')
resource starterProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  name: 'starter'
  parent: apiManagement
  properties: {
    displayName: 'Starter'
    description: 'Starter product for developers'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
    subscriptionsLimit: 1
  }
}

@description('Unlimited product')
resource unlimitedProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
  name: 'unlimited'
  parent: apiManagement
  properties: {
    displayName: 'Unlimited'
    description: 'Unlimited product for internal use'
    subscriptionRequired: true
    approvalRequired: true
    state: 'published'
    subscriptionsLimit: 1
  }
}

@description('Link Echo API to Starter product')
resource starterProductApi 'Microsoft.ApiManagement/service/products/apis@2023-05-01-preview' = {
  name: 'echo-api'
  parent: starterProduct
  dependsOn: [
    echoApi
  ]
}

@description('Link Echo API to Unlimited product')
resource unlimitedProductApi 'Microsoft.ApiManagement/service/products/apis@2023-05-01-preview' = {
  name: 'echo-api'
  parent: unlimitedProduct
  dependsOn: [
    echoApi
  ]
}

@description('All APIs policy')
resource allApisPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: echoApi
  properties: {
    value: '''
      <policies>
        <inbound>
          <base />
          <set-header name="X-Powered-By" exists-action="delete" />
          <set-header name="X-AspNet-Version" exists-action="delete" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
        </outbound>
        <on-error>
          <base />
        </on-error>
      </policies>
    '''
    format: 'xml'
  }
}

@description('Named value for backend URL')
resource backendUrlNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  name: 'backend-url'
  parent: apiManagement
  properties: {
    displayName: 'backend-url'
    value: 'https://api.example.com'
    secret: false
  }
}

@description('Diagnostic settings for API Management')
resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${apimName}-diagnostics'
  scope: apiManagement
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
      {
        categoryGroup: 'audit'
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

@description('The resource ID of the API Management service')
output apimId string = apiManagement.id

@description('The name of the API Management service')
output apimName string = apiManagement.name

@description('The gateway URL of the API Management service')
output gatewayUrl string = apiManagement.properties.gatewayUrl

@description('The developer portal URL')
output developerPortalUrl string = enableDeveloperPortal ? apiManagement.properties.developerPortalUrl : ''

@description('The management API URL')
output managementApiUrl string = apiManagement.properties.managementApiUrl

@description('The portal URL')
output portalUrl string = apiManagement.properties.portalUrl

@description('The SCM URL')
output scmUrl string = apiManagement.properties.scmUrl

@description('The principal ID of the system-assigned managed identity')
output identityPrincipalId string = enableSystemIdentity ? apiManagement.identity.principalId : ''

@description('The tenant ID of the system-assigned managed identity')
output identityTenantId string = enableSystemIdentity ? apiManagement.identity.tenantId : ''

@description('The public IP addresses')
output publicIpAddresses array = apiManagement.properties.publicIPAddresses

@description('The private IP addresses')
output privateIpAddresses array = virtualNetworkType != 'None' ? apiManagement.properties.privateIPAddresses : []
