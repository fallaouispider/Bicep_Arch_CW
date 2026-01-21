// =========================================
// AZURE KUBERNETES SERVICE (AKS) MODULE
// =========================================
// This module creates:
// - AKS cluster with system node pool
// - Azure CNI networking
// - Application Gateway Ingress Controller (AGIC) addon
// - System-assigned managed identity
// - Azure Monitor integration
// Following AKS best practices
// =========================================

metadata description = 'Deploys Azure Kubernetes Service with AGIC addon'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the AKS cluster')
@minLength(1)
@maxLength(63)
param aksClusterName string

@description('Azure region for the AKS cluster')
param location string = resourceGroup().location

@description('DNS prefix for the AKS cluster')
@minLength(1)
@maxLength(54)
param dnsPrefix string

@description('Kubernetes version')
param kubernetesVersion string = '1.29.0'

@description('Node pool name')
@minLength(1)
@maxLength(12)
param nodePoolName string = 'systempool'

@description('Number of nodes in the system node pool')
@minValue(1)
@maxValue(100)
param nodeCount int = 3

@description('VM size for the system node pool')
param nodeVmSize string = 'Standard_D2s_v3'

@description('OS disk size in GB')
@minValue(0)
@maxValue(2048)
param osDiskSizeGB int = 128

@description('OS disk type')
@allowed([
  'Managed'
  'Ephemeral'
])
param osDiskType string = 'Managed'

@description('Maximum number of pods per node')
@minValue(10)
@maxValue(250)
param maxPods int = 30

@description('Resource ID of the VNet subnet for AKS nodes')
param subnetId string

@description('Enable auto-scaling')
param enableAutoScaling bool = true

@description('Minimum number of nodes for auto-scaling')
@minValue(1)
@maxValue(100)
param minCount int = 1

@description('Maximum number of nodes for auto-scaling')
@minValue(1)
@maxValue(1000)
param maxCount int = 5

@description('Network plugin')
@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'azure'

@description('Network policy')
@allowed([
  'azure'
  'calico'
  ''
])
param networkPolicy string = 'azure'

@description('Service CIDR for Kubernetes services')
param serviceCidr string = '10.2.0.0/16'

@description('DNS service IP address')
param dnsServiceIP string = '10.2.0.10'

@description('Enable AGIC addon')
param enableAGIC bool = true

@description('Resource ID of the Application Gateway for AGIC')
param applicationGatewayId string = ''

@description('Enable Azure Monitor for containers')
param enableMonitoring bool = true

@description('Log Analytics Workspace ID for monitoring')
param logAnalyticsWorkspaceId string = ''

@description('Enable pod security policy (deprecated, use Azure Policy instead)')
param enablePodSecurityPolicy bool = false

@description('Enable RBAC')
param enableRBAC bool = true

@description('Enable Azure AD integration')
param enableAzureAD bool = false

@description('Enable private cluster')
param enablePrivateCluster bool = false

@description('SKU tier for AKS')
@allowed([
  'Free'
  'Standard'
  'Premium'
])
param skuTier string = 'Free'

@description('Tags to apply to all resources')
param tags object = {}

@description('Enable diagnostic settings')
param enableDiagnostics bool = false

@description('Log Analytics Workspace ID for diagnostics')
param diagnosticsWorkspaceId string = ''

// =========================================
// RESOURCES
// =========================================

@description('Azure Kubernetes Service cluster')
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: aksClusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Base'
    tier: skuTier
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: dnsPrefix
    enableRBAC: enableRBAC
    enablePodSecurityPolicy: enablePodSecurityPolicy
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: networkPolicy
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    apiServerAccessProfile: enablePrivateCluster ? {
      enablePrivateCluster: true
      enablePrivateClusterPublicFQDN: false
    } : {
      enablePrivateCluster: false
    }
    agentPoolProfiles: [
      {
        name: nodePoolName
        count: nodeCount
        vmSize: nodeVmSize
        osDiskSizeGB: osDiskSizeGB
        osDiskType: osDiskType
        vnetSubnetID: subnetId
        maxPods: maxPods
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        enableAutoScaling: enableAutoScaling
        minCount: enableAutoScaling ? minCount : null
        maxCount: enableAutoScaling ? maxCount : null
        enableNodePublicIP: false
        enableEncryptionAtHost: false
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    addonProfiles: {
      ingressApplicationGateway: enableAGIC && !empty(applicationGatewayId) ? {
        enabled: true
        config: {
          applicationGatewayId: applicationGatewayId
        }
      } : {
        enabled: false
      }
      omsagent: enableMonitoring && !empty(logAnalyticsWorkspaceId) ? {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      } : {
        enabled: false
      }
      azurepolicy: {
        enabled: false
      }
      azureKeyvaultSecretsProvider: {
        enabled: false
      }
    }
    aadProfile: enableAzureAD ? {
      managed: true
      enableAzureRBAC: true
    } : null
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
    disableLocalAccounts: enableAzureAD
  }
}

@description('Diagnostic settings for AKS cluster')
resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(diagnosticsWorkspaceId)) {
  name: '${aksClusterName}-diagnostics'
  scope: aksCluster
  properties: {
    workspaceId: diagnosticsWorkspaceId
    logs: [
      {
        category: 'kube-apiserver'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'kube-audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'kube-controller-manager'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'kube-scheduler'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'cluster-autoscaler'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'guard'
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

@description('The resource ID of the AKS cluster')
output aksClusterId string = aksCluster.id

@description('The name of the AKS cluster')
output aksClusterName string = aksCluster.name

@description('The FQDN of the AKS cluster')
output aksClusterFqdn string = aksCluster.properties.fqdn

@description('The Kubernetes version')
output kubernetesVersion string = aksCluster.properties.kubernetesVersion

@description('The principal ID of the AKS cluster managed identity')
output identityPrincipalId string = aksCluster.identity.principalId

@description('The tenant ID of the AKS cluster managed identity')
output identityTenantId string = aksCluster.identity.tenantId

@description('The node resource group name')
output nodeResourceGroup string = aksCluster.properties.nodeResourceGroup

@description('The AGIC addon identity object ID')
output agicIdentityObjectId string = enableAGIC && !empty(applicationGatewayId) ? aksCluster.properties.addonProfiles.ingressApplicationGateway.identity.objectId : ''

@description('The AGIC addon identity client ID')
output agicIdentityClientId string = enableAGIC && !empty(applicationGatewayId) ? aksCluster.properties.addonProfiles.ingressApplicationGateway.identity.clientId : ''
