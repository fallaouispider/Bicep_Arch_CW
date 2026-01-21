// =========================================
// APPLICATION GATEWAY MODULE
// =========================================
// This module creates:
// - Public IP for Application Gateway
// - Application Gateway v2 with WAF capabilities
// - Backend pools, HTTP settings, listeners, and routing rules
// - User-assigned managed identity for AGIC integration
// Following Azure Application Gateway best practices
// =========================================

metadata description = 'Deploys Azure Application Gateway v2 with AGIC support'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the Application Gateway')
@minLength(1)
@maxLength(80)
param appGatewayName string

@description('Azure region for the Application Gateway')
param location string = resourceGroup().location

@description('SKU name for Application Gateway')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuName string = 'Standard_v2'

@description('SKU tier for Application Gateway')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuTier string = 'Standard_v2'

@description('Minimum capacity units for autoscaling')
@minValue(0)
@maxValue(125)
param minCapacity int = 0

@description('Maximum capacity units for autoscaling')
@minValue(2)
@maxValue(125)
param maxCapacity int = 10

@description('Name of the Public IP for Application Gateway')
param publicIpName string

@description('Resource ID of the Application Gateway subnet')
param subnetId string

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable diagnostic settings')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics')
param logAnalyticsWorkspaceId string = ''

@description('Enable Web Application Firewall')
param enableWaf bool = false

@description('WAF mode')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Detection'

@description('WAF rule set type')
param wafRuleSetType string = 'OWASP'

@description('WAF rule set version')
param wafRuleSetVersion string = '3.2'

@description('Enable HTTP/2 support')
param enableHttp2 bool = true

@description('Request timeout in seconds')
@minValue(1)
@maxValue(86400)
param requestTimeout int = 30

// =========================================
// VARIABLES
// =========================================

var frontendPortName = 'frontendPort'
var frontendIPConfigurationName = 'frontendIPConfiguration'
var backendAddressPoolName = 'defaultBackendPool'
var backendHttpSettingsName = 'defaultHttpSettings'
var httpListenerName = 'httpListener'
var requestRoutingRuleName = 'defaultRoutingRule'
var probeName = 'defaultHealthProbe'

// =========================================
// RESOURCES
// =========================================

@description('User-assigned managed identity for Application Gateway (required for AGIC)')
resource appGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${appGatewayName}-identity'
  location: location
  tags: tags
}

@description('Public IP for Application Gateway frontend')
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: toLower(appGatewayName)
    }
  }
}

@description('Application Gateway v2')
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: appGatewayName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGatewayIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: skuName
      tier: skuTier
    }
    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
    enableHttp2: enableHttp2
    gatewayIPConfigurations: [
      {
        name: 'gatewayIPConfiguration'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIPConfigurationName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: 80
        }
      }
      {
        name: 'frontendPortHttps'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendAddressPoolName
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: backendHttpSettingsName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: requestTimeout
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, probeName)
          }
        }
      }
    ]
    httpListeners: [
      {
        name: httpListenerName
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, frontendIPConfigurationName)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, frontendPortName)
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: requestRoutingRuleName
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, httpListenerName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, backendAddressPoolName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, backendHttpSettingsName)
          }
        }
      }
    ]
    probes: [
      {
        name: probeName
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: enableWaf ? {
      enabled: true
      firewallMode: wafMode
      ruleSetType: wafRuleSetType
      ruleSetVersion: wafRuleSetVersion
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    } : null
  }
}

@description('Diagnostic settings for Application Gateway')
resource appGatewayDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${appGatewayName}-diagnostics'
  scope: applicationGateway
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

@description('Diagnostic settings for Public IP')
resource publicIpDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${publicIpName}-diagnostics'
  scope: publicIp
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

@description('The resource ID of the Application Gateway')
output appGatewayId string = applicationGateway.id

@description('The name of the Application Gateway')
output appGatewayName string = applicationGateway.name

@description('The public IP address of the Application Gateway')
output publicIpAddress string = publicIp.properties.ipAddress

@description('The FQDN of the Application Gateway')
output fqdn string = publicIp.properties.dnsSettings.fqdn

@description('The resource ID of the Application Gateway managed identity')
output identityId string = appGatewayIdentity.id

@description('The principal ID of the Application Gateway managed identity')
output identityPrincipalId string = appGatewayIdentity.properties.principalId

@description('The resource ID of the Public IP')
output publicIpId string = publicIp.id

@description('The name of the Public IP')
output publicIpName string = publicIp.name
