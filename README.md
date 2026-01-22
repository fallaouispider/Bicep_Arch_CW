# Azure Bicep Infrastructure - VNet Architecture

Professional Azure infrastructure deployment using Bicep with modular design, following Azure Well-Architected Framework principles.

## 📋 Overview

This project deploys a complete Azure networking infrastructure with:

- **Resource Group** - Logical container for all resources
- **Virtual Network (VNet)** - Isolated network environment with multiple subnets
- **Subnets** - Network segmentation (application subnet and Application Gateway subnet)
- **Network Security Groups (NSG)** - Network-level security controls
- **Azure Cosmos DB** - NoSQL Serverless database with private endpoint integration
- **Azure Service Bus** - Standard Tier messaging service for reliable message delivery
- **Azure SQL Server** - Standard Tier SQL database with multiple databases and private endpoint
- **Application Gateway v2** - Layer 7 load balancer with Web Application Firewall (WAF) support
- **Azure Kubernetes Service (AKS)** - Managed Kubernetes cluster with AGIC addon for ingress
- **API Management** - Developer Tier API gateway with VNet integration for API management and security
- **Azure Container Registry (ACR)** - Container registry for Docker images with private endpoint support
- **DevOps Runner VM** - Virtual machine for Azure DevOps pipeline agents with managed identity

## 🏗️ Architecture

```
Subscription
└── Resource Group (rg-{workload}-{env}-{region}-{instance})
    ├── Virtual Network (vnet-{workload}-{env}-{region}-{instance})
    │   ├── Application Subnet (snet-{workload}-{env}-{region}-{instance})
    │   │   ├── Service Endpoints (Cosmos DB, Service Bus, SQL, Storage, Key Vault)
    │   │   ├── AKS Nodes (CNI networking)
    │   │   └── Private Endpoints
    │   │       ├── cosmos-{workload}-{env}-{region}-{instance}-pe
    │   │       ├── sb-{workload}-{env}-{region}-{instance}-pe (Premium SKU)
    │   │       └── sql-{workload}-{env}-{region}-{instance}-pe
    │   └── Application Gateway Subnet (snet-appgw-{workload}-{env}-{region}-{instance})
    │       └── Application Gateway with Public IP
    ├── Network Security Groups
    │   ├── nsg-{workload}-{env}-{region}-{instance}
    │   └── nsg-{workload}-{env}-{region}-{instance}-appgw
    ├── Azure Cosmos DB (cosmos-{workload}-{env}-{region}-{instance})
    │   ├── NoSQL API (Serverless)
    │   ├── SQL Database
    │   ├── Containers (configurable)
    │   └── Private Endpoint Connection
    ├── Azure Service Bus (sb-{workload}-{env}-{region}-{instance})
    │   ├── Standard Tier
    │   ├── Queues (configurable)
    │   ├── Topics & Subscriptions (configurable)
    │   └── Service Endpoint Integration
    ├── Azure SQL Server (sql-{workload}-{env}-{region}-{instance})
    │   ├── SQL Databases (configurable)
    │   │   ├── CWDB (General Purpose Gen5, 2 vCores)
    │   │   ├── CW-Utility (General Purpose Gen5, 2 vCores)
    │   │   └── sql01-nonprd-emea-db (General Purpose Gen5, 2 vCores)
    │   ├── Transparent Data Encryption (TDE)
    │   ├── Automated Backups
    │   ├── Microsoft Entra ID Admin (optional)
    │   └── Private Endpoint Connection
    ├── Application Gateway v2 (appgw-{workload}-{env}-{region}-{instance})
    │   ├── Standard_v2 or WAF_v2 SKU
    │   ├── Autoscaling (0-10 capacity units)
    │   ├── Public IP (pip-appgw-{workload}-{env}-{region}-{instance})
    │   ├── Backend Pools (managed by AGIC)
    │   ├── HTTP/HTTPS Listeners
    │   ├── Health Probes
    │   └── User-Assigned Managed Identity
    └── Azure Kubernetes Service (aks-{workload}-{env}-{region}-{instance})
        ├── System Node Pool (1-5 nodes, autoscaling)
        ├── Azure CNI Networking
        ├── Azure Network Policy
        ├── AGIC Addon (Application Gateway Ingress Controller)
        ├── Azure Monitor for Containers (optional)
        ├── System-Assigned Managed Identity
        ├── Kubernetes Version 1.29.0
        └── Node Resource Group (auto-created)
    └── API Management (apim-{workload}-{env}-{region}-{instance})
        ├── Developer Tier (or Standard/Premium)
        ├── VNet Integration (External mode)
        ├── Gateway URL (public or private)
        ├── Developer Portal
        ├── Management API
        └── System-Assigned Managed Identity
    └── Azure Container Registry (acr{workload}{env}{region}{instance})
        ├── Standard or Premium SKU
        ├── Admin User (optional)
        ├── Private Endpoint (Premium SKU)
        ├── Geo-Replication (Premium SKU)
        ├── Zone Redundancy (Premium SKU)
        ├── Content Trust & Quarantine (Premium SKU)
        └── System-Assigned Managed Identity
    └── DevOps Runner VM (vm-devops-{workload}-{env}-{region}-{instance})
        ├── Standard_D4s_v3 (configurable)
        ├── Linux or Windows OS
        ├── System-Assigned Managed Identity
        ├── Premium SSD OS Disk (128 GB)
        ├── Data Disk (256 GB, optional)
        ├── Network Interface (private IP)
        ├── Public IP (optional)
        ├── Azure DevOps Agent (auto-installed)
        └── Boot Diagnostics
```

### Address Space Planning

| Environment | VNet CIDR | App Subnet CIDR | AppGW Subnet CIDR | Available IPs |
|-------------|-----------|-----------------|-------------------|---------------|
| Development | 10.1.0.0/16 | 10.1.0.0/24 | 10.1.1.0/24 | 251 per subnet |
| Production | 10.0.0.0/16 | 10.0.0.0/24 | 10.0.1.0/24 | 251 per subnet |

**Note**: AKS service CIDR (10.2.0.0/16) is separate from VNet address space.

## 📁 Project Structure

```
Bicep_Arch_CW/
├── main.bicep                  # Main orchestration template (subscription scope)
├── main.dev.bicepparam         # Development environment parameters
├── main.prod.bicepparam        # Production environment parameters
├── bicepconfig.json            # Bicep linter configuration
├── modules/
│   ├── networking/
│   │   ├── vnet.bicep         # VNet with multiple subnets and NSGs
│   │   └── appgateway.bicep   # Application Gateway v2 with WAF
│   ├── database/
│   │   ├── cosmosdb.bicep     # Cosmos DB NoSQL Serverless module
│   │   └── sqlserver.bicep    # Azure SQL Server with databases module
│   ├── messaging/
│   │   └── servicebus.bicep   # Service Bus Standard Tier module
│   ├── compute/
│   │   ├── aks.bicep          # Azure Kubernetes Service with AGIC addon
│   │   ├── acr.bicep          # Azure Container Registry module
│   │   └── vm.bicep           # Virtual Machine for DevOps runners
│   └── integration/
│       └── apim.bicep         # API Management module
└── README.md                   # This file
```

## 🚀 Deployment

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (version 2.20.0 or later)
- [Bicep CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (version 0.4.0 or later)
- Azure subscription with Contributor or Owner role
- PowerShell 7+ or Bash shell

### Quick Start

#### 1. Login to Azure

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

#### 2. Deploy Development Environment

```powershell
az deployment sub create `
  --location eastus2 `
  --template-file main.bicep `
  --parameters main.dev.bicepparam `
  --name "vnet-infrastructure-dev-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
```

#### 3. Deploy Production Environment

**Important:** Update the `logAnalyticsWorkspaceId` in [main.prod.bicepparam](main.prod.bicepparam) before deploying to production.

```powershell
az deployment sub create `
  --location eastus2 `
  --template-file main.bicep `
  --parameters main.prod.bicepparam `
  --name "vnet-infrastructure-prod-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
```

### Bash Deployment

```bash
# Development
az deployment sub create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters main.dev.bicepparam \
  --name "vnet-infrastructure-dev-$(date +%Y%m%d-%H%M%S)"

# Production
az deployment sub create \
  --location eastus2 \
  --template-file main.bicep \
  --parameters main.prod.bicepparam \
  --name "vnet-infrastructure-prod-$(date +%Y%m%d-%H%M%S)"
```

## ⚙️ Configuration

### Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `workloadName` | string | Name of the workload (3-15 chars) | - |
| `environmentType` | string | Environment: dev, test, staging, prod | - |
| `location` | string | Azure region | deployment location |
| `instanceNumber` | string | Instance number (001-999) | 001 |
| `vnetAddressPrefix` | string | VNet CIDR (e.g., 10.0.0.0/16) | - |
| `subnetAddressPrefix` | string | Subnet CIDR (e.g., 10.0.0.0/24) | - |
| `tags` | object | Resource tags | {} |
| `enableDiagnostics` | bool | Enable diagnostic settings | false |
| `logAnalyticsWorkspaceId` | string | Log Analytics resource ID | '' |
| `deployCosmosDb` | bool | Deploy Cosmos DB | true |
| `cosmosDbDatabaseName` | string | Cosmos DB database name | 'appdb' |
| `cosmosDbContainers` | array | Array of containers to create | [] |
| `enableCosmosDbPrivateEndpoint` | bool | Enable private endpoint for Cosmos DB | true |
| `enableCosmosDbFreeTier` | bool | Enable Cosmos DB free tier | false |
| `deployServiceBus` | bool | Deploy Service Bus | true |
| `serviceBusSku` | string | Service Bus SKU (Basic/Standard/Premium) | 'Standard' |
| `serviceBusQueues` | array | Array of queues to create | [] |
| `serviceBusTopics` | array | Array of topics to create | [] |
| `enableServiceBusPrivateEndpoint` | bool | Enable private endpoint for Service Bus | false |
| `serviceBusZoneRedundant` | bool | Enable zone redundancy (Premium SKU) | false |
| `deploySqlServer` | bool | Deploy Azure SQL Server | true |
| `sqlServerAdminLogin` | string | SQL Server administrator login name | - |
| `sqlServerAdminPassword` | securestring | SQL Server administrator password | - |
| `sqlDatabases` | array | Array of SQL databases to create | [] |
| `enableSqlServerPrivateEndpoint` | bool | Enable private endpoint for SQL Server | true |
| `sqlServerPublicNetworkAccess` | bool | Allow public network access | false |
| `sqlServerEntraAdminObjectId` | string | Entra ID admin object ID (optional) | '' |
| `sqlServerEntraAdminLogin` | string | Entra ID admin login name (optional) | '' |
| `deployAppGateway` | bool | Deploy Application Gateway | true |
| `appGatewaySubnetAddressPrefix` | string | Application Gateway subnet CIDR | - |
| `appGatewaySku` | string | Application Gateway SKU (Standard_v2/WAF_v2) | 'Standard_v2' |
| `appGatewayMinCapacity` | int | Minimum autoscale capacity (0-125) | 0 |
| `appGatewayMaxCapacity` | int | Maximum autoscale capacity (2-125) | 10 |
| `enableWaf` | bool | Enable Web Application Firewall | false |
| `deployAKS` | bool | Deploy Azure Kubernetes Service | true |
| `kubernetesVersion` | string | Kubernetes version | '1.29.0' |
| `aksNodeVmSize` | string | AKS node VM size | 'Standard_D2s_v3' |
| `aksNodeCount` | int | Number of AKS nodes | 3 |
| `enableAksAutoScaling` | bool | Enable AKS autoscaling | true |
| `aksMinNodeCount` | int | Minimum nodes for autoscaling | 1 |
| `aksMaxNodeCount` | int | Maximum nodes for autoscaling | 5 |
| `aksServiceCidr` | string | Kubernetes service CIDR | '10.2.0.0/16' |
| `aksDnsServiceIP` | string | Kubernetes DNS service IP | '10.2.0.10' |
| `enableAGIC` | bool | Enable AGIC addon | true |
| `enableAksMonitoring` | bool | Enable Azure Monitor for containers | true |
| `aksSku` | string | AKS SKU tier (Free/Standard/Premium) | 'Free' |
| `deployApiManagement` | bool | Deploy API Management | true |
| `apimSku` | string | APIM SKU (Consumption/Developer/Basic/Standard/Premium) | 'Developer' |
| `apimCapacity` | int | APIM SKU capacity (0-12) | 1 |
| `apimPublisherEmail` | string | APIM publisher email address | - |
| `apimPublisherName` | string | APIM publisher organization name | - |
| `apimVirtualNetworkType` | string | VNet integration type (None/External/Internal) | 'External' |

### Customization

#### Modify Network Address Spaces

Edit the parameter files:
- **Development**: [main.dev.bicepparam](main.dev.bicepparam)
- **Production**: [main.prod.bicepparam](main.prod.bicepparam)

```bicep
param vnetAddressPrefix = '10.2.0.0/16'  // Custom VNet range
param subnetAddressPrefix = '10.2.1.0/24'  // Custom Subnet range
```

#### Update NSG Security Rules

Edit [modules/networking/vnet.bicep](modules/networking/vnet.bicep) to add/modify security rules:

```bicep
{
  name: 'AllowCustomPort'
  properties: {
    priority: 140
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '8080'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: '*'
  }
}
```

#### Add Resource Tags

Update tags in parameter files:

```bicep
param tags = {
  Application: 'YourApp'
  CostCenter: 'IT-12345'
  Owner: 'yourteam@company.com'
  Criticality: 'High'
  DataClassification: 'Confidential'
}
```

#### Configure Cosmos DB Containers

Edit the parameter files to add or modify containers:

```bicep
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
    defaultTtl: 86400  // 24 hours
  }
]
```

#### Enable Cosmos DB Free Tier

For development, you can enable the free tier (400 RU/s, 25 GB storage):

```bicep
param enableCosmosDbFreeTier = true
```

**Note**: Only one free tier Cosmos DB account is allowed per Azure subscription.

#### Configure Service Bus Queues and Topics

Edit the parameter files to add or modify queues and topics:

```bicep
// Queues configuration
param serviceBusQueues = [
  {
    name: 'orders'
    maxSizeInMegabytes: 2048
    maxDeliveryCount: 10
    lockDuration: 'PT1M'  // 1 minute
    defaultMessageTimeToLive: 'P14D'  // 14 days
    deadLetteringOnMessageExpiration: true
    requiresDuplicateDetection: true
  }
  {
    name: 'notifications'
    maxSizeInMegabytes: 1024
    maxDeliveryCount: 5
  }
]

// Topics with subscriptions
param serviceBusTopics = [
  {
    name: 'events'
    maxSizeInMegabytes: 2048
    supportOrdering: true
    subscriptions: [
      {
        name: 'processor'
        maxDeliveryCount: 10
        lockDuration: 'PT1M'
      }
    ]
  }
]
```

#### Upgrade to Premium SKU

For private endpoint support and zone redundancy:

```bicep
param serviceBusSku = 'Premium'
param enableServiceBusPrivateEndpoint = true
param serviceBusZoneRedundant = true
```

**Note**: Premium SKU provides 1 messaging unit with higher throughput and advanced features.

#### Configure SQL Server Databases

Edit the parameter files to add or modify SQL databases:

```bicep
param deploySqlServer = true
param sqlServerAdminLogin = 'sqladmin'
param sqlServerAdminPassword = '' // Provide via secure method

// Database configuration with General Purpose Gen5, 2 vCores
param sqlDatabases = [
  {
    name: 'CWDB'
    skuName: 'GP_Gen5_2'  // General Purpose Gen5, 2 vCores
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 107374182400  // 100 GB
    backupRetentionDays: 35
    backupStorageRedundancy: 'Geo'  // Options: Local, Zone, Geo
    zoneRedundant: false
    licenseType: 'LicenseIncluded'  // or 'BasePrice' for AHUB
  }
  {
    name: 'CW-Utility'
    skuName: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    vCores: 2
    maxSizeBytes: 53687091200  // 50 GB
    backupRetentionDays: 7
  }
]
```

**Available SKUs:**
- **General Purpose**: `GP_Gen5_2`, `GP_Gen5_4`, `GP_Gen5_8`, `GP_Gen5_16`, `GP_Gen5_32`
- **Business Critical**: `BC_Gen5_2`, `BC_Gen5_4`, `BC_Gen5_8`, `BC_Gen5_16`
- **Hyperscale**: `HS_Gen5_2`, `HS_Gen5_4`, `HS_Gen5_8`

#### Enable SQL Server Private Endpoint

For secure VNet-only access:

```bicep
param enableSqlServerPrivateEndpoint = true
param sqlServerPublicNetworkAccess = false
```

#### Configure Microsoft Entra ID Admin

For production environments, configure Entra ID authentication:

```bicep
param sqlServerEntraAdminObjectId = '12345678-1234-1234-1234-123456789012'
param sqlServerEntraAdminLogin = 'admin@yourcompany.com'
```

**Best Practice**: Always use Entra ID authentication in production and disable SQL authentication when possible.

#### Configure Application Gateway

Configure Application Gateway with autoscaling:

```bicep
param deployAppGateway = true
param appGatewaySubnetAddressPrefix = '10.0.1.0/24'  // Dedicated subnet required
param appGatewaySku = 'WAF_v2'  // Standard_v2 or WAF_v2
param appGatewayMinCapacity = 2
param appGatewayMaxCapacity = 10
param enableWaf = true  // Enable Web Application Firewall
```

**Application Gateway Features:**
- **Standard_v2**: Layer 7 load balancing, autoscaling, zone redundancy
- **WAF_v2**: All Standard_v2 features plus Web Application Firewall
- **Autoscaling**: 0-125 capacity units (0 min = serverless)
- **Public IP**: Static Standard SKU with DNS label
- **User-Assigned Identity**: Required for AGIC integration

#### Configure AKS with AGIC

Deploy AKS cluster with Application Gateway Ingress Controller:

```bicep
param deployAKS = true
param kubernetesVersion = '1.29.0'
param aksNodeVmSize = 'Standard_D4s_v3'
param aksNodeCount = 3
param enableAksAutoScaling = true
param aksMinNodeCount = 3
param aksMaxNodeCount = 10
param aksServiceCidr = '10.2.0.0/16'  // Must not overlap with VNet
param aksDnsServiceIP = '10.2.0.10'   // Must be within service CIDR
param enableAGIC = true  // Enable Application Gateway Ingress Controller
param enableAksMonitoring = true
param aksSku = 'Standard'  // Free, Standard, or Premium
```

**AKS Configuration:**
- **Network Plugin**: Azure CNI (advanced networking)
- **Network Policy**: Azure Network Policy
- **Node Pool**: System mode with autoscaling
- **AGIC Addon**: Automatically configured with Application Gateway
- **Monitoring**: Azure Monitor for containers (optional)
- **Upgrade Channel**: Stable

#### Configure API Management

Deploy API Management with VNet integration:

```bicep
param deployApiManagement = true
param apimSku = 'Developer'  // Developer for non-prod, Standard/Premium for prod
param apimCapacity = 1
param apimPublisherEmail = 'api-admin@contoso.com'
param apimPublisherName = 'Contoso'
param apimVirtualNetworkType = 'External'  // None, External, or Internal
```

**API Management SKU Comparison:**
- **Consumption**: Serverless, pay-per-execution, no VNet support
- **Developer**: For testing, 1 unit, no SLA, supports VNet
- **Basic**: Production use, 2 units max, 99.95% SLA
- **Standard**: Production use, 4 units max, 99.95% SLA  
- **Premium**: Enterprise, 12 units max, 99.99% SLA, multi-region, availability zones

**VNet Integration Modes:**
- **External**: Gateway accessible from internet, backend in VNet
- **Internal**: Gateway only accessible from within VNet or via VPN/ExpressRoute
- **None**: No VNet integration, fully public

**Built-in Features:**
- Developer portal for API documentation
- Products for grouping APIs
- Subscriptions for API access control
- Policies for transformation and security
- Named values for configuration management
- Version sets for API versioning
- Application Insights integration

#### Configure Azure Container Registry

Deploy ACR for container image storage:

```bicep
param deployACR = true
param acrSku = 'Premium'  // Basic, Standard, or Premium
param enableAcrAdminUser = false  // Enable admin user for simple scenarios
param enableAcrPrivateEndpoint = true  // Requires Premium SKU
param acrPublicNetworkAccess = false  // Disable public access for security
param acrRetentionDays = 30  // Image retention policy (Premium only)
param enableAcrZoneRedundancy = true  // Zone redundancy (Premium only)
```

**ACR SKU Comparison:**
- **Basic**: 10 GB storage, 10 webhooks, suitable for learning/testing
- **Standard**: 100 GB storage, 100 webhooks, production-ready
- **Premium**: 500 GB storage, 500 webhooks, geo-replication, private endpoints, zone redundancy

**Features:**
- Content trust for image signing (Premium)
- Retention policies for untagged manifests (Premium)
- Quarantine policy for image scanning (Premium)
- Anonymous pull access (optional)
- Azure RBAC for fine-grained access control
- System-assigned managed identity

#### Configure DevOps Runner VM

Deploy VM for Azure DevOps pipeline agents:

```bicep
param deployDevOpsVM = true
param devOpsVmSize = 'Standard_D4s_v3'  // 4 vCPU, 16 GB RAM
param devOpsVmOsType = 'Linux'  // Linux or Windows
param devOpsVmAdminUsername = 'azureuser'
param devOpsVmAdminPassword = ''  // Set via command line
param devOpsVmSshPublicKey = ''  // Optional SSH key for Linux
param enableDevOpsVmPublicIp = false  // Usually false for security
param devOpsVmOsDiskSizeGB = 256  // OS disk size
param enableDevOpsVmDataDisk = true  // Additional storage
param devOpsVmDataDiskSizeGB = 512  // Data disk size
param devOpsOrgUrl = 'https://dev.azure.com/yourorg'  // DevOps organization
param devOpsPat = ''  // Personal Access Token (set securely)
param devOpsPoolName = 'Production'  // Agent pool name
```

**VM Features:**
- System-assigned managed identity for Azure resource access
- Trusted Launch with Secure Boot and vTPM
- Automatic OS patching
- Boot diagnostics enabled
- Azure DevOps agent auto-installation
- Premium SSD for optimal performance
- Integration with VNet NSG for security

#### Configure Application Gateway

Configure Application Gateway with autoscaling:

```bicep
param deployAppGateway = true
param appGatewaySubnetAddressPrefix = '10.0.1.0/24'  // Dedicated subnet required
param appGatewaySku = 'WAF_v2'  // Standard_v2 or WAF_v2
param appGatewayMinCapacity = 2
param appGatewayMaxCapacity = 10
param enableWaf = true  // Enable Web Application Firewall
```

**Application Gateway Features:**
- **Standard_v2**: Layer 7 load balancing, autoscaling, zone redundancy
- **WAF_v2**: All Standard_v2 features plus Web Application Firewall
- **Autoscaling**: 0-125 capacity units (0 min = serverless)
- **Public IP**: Static Standard SKU with DNS label
- **User-Assigned Identity**: Required for AGIC integration

#### Configure AKS with AGIC

Deploy AKS cluster with Application Gateway Ingress Controller:

```bicep
param deployAKS = true
param kubernetesVersion = '1.29.0'
param aksNodeVmSize = 'Standard_D4s_v3'
param aksNodeCount = 3
param enableAksAutoScaling = true
param aksMinNodeCount = 3
param aksMaxNodeCount = 10
param aksServiceCidr = '10.2.0.0/16'  // Must not overlap with VNet
param aksDnsServiceIP = '10.2.0.10'   // Must be within service CIDR
param enableAGIC = true  // Enable Application Gateway Ingress Controller
param enableAksMonitoring = true
param aksSku = 'Standard'  // Free, Standard, or Premium
```

**AKS Configuration:**
- **Network Plugin**: Azure CNI (advanced networking)
- **Network Policy**: Azure Network Policy
- **Node Pool**: System mode with autoscaling
- **AGIC Addon**: Automatically configured with Application Gateway
- **Monitoring**: Azure Monitor for containers (optional)
- **Upgrade Channel**: Stable

## 🔒 Security Features

### Network Security Group (NSG)

Default baseline rules implemented:

**Inbound Rules:**
- ✅ HTTPS (443) - Priority 100
- ✅ HTTP (80) - Priority 110
- ✅ SSH (22) from VNet - Priority 120
- ✅ RDP (3389) from VNet - Priority 130
- ❌ Deny all other inbound - Priority 4096

**Outbound Rules:**
- ✅ VNet traffic - Priority 100
- ✅ Internet access - Priority 110
- ✅ Azure Cloud services - Priority 120

### Best Practices Applied

- ✅ Principle of least privilege
- ✅ Defense in depth
- ✅ Private endpoint network policies disabled for PaaS integration
- ✅ Subnet-level NSG association
- ✅ Diagnostic logging enabled for production
- ✅ Consistent naming conventions
- ✅ Comprehensive resource tagging

### Cosmos DB Security

**Security Features:**
- ✅ **Serverless capacity mode** - Cost-effective for variable workloads
- ✅ **Private endpoint** - Traffic stays within VNet
- ✅ **Service endpoints** - Optimized routing to Cosmos DB
- ✅ **Public network access disabled** - When private endpoint is enabled
- ✅ **TLS 1.2 minimum** - Secure data in transit
- ✅ **Continuous backup (30 days)** - Point-in-time restore capability
- ✅ **System-assigned managed identity** - For Azure RBAC integration
- ✅ **Local auth disabled** - Enforce Entra ID authentication (production)
- ✅ **Key-based metadata write disabled** - Prevent unauthorized schema changes

**Best Practices:**
- Use partition keys effectively for optimal performance
- Leverage serverless for unpredictable workloads
- Enable private endpoints in production
- Use managed identities instead of connection strings
- Implement proper data retention with TTL
- Monitor RU consumption and throttling

### Service Bus Security

**Security Features:**
- ✅ **Standard Tier** - Cost-effective for most workloads
- ✅ **Service endpoint integration** - Optimized routing within VNet
- ✅ **System-assigned managed identity** - For Azure RBAC integration
- ✅ **TLS 1.2 minimum** - Secure data in transit
- ✅ **Dead-letter queues** - Automatic handling of failed messages
- ✅ **Duplicate detection** - Prevents message duplication
- ✅ **At-rest encryption** - Automatic encryption with Microsoft-managed keys
- ✅ **Private endpoint support** - Available with Premium SKU
- ✅ **Zone redundancy** - High availability with Premium SKU

**Best Practices:**
- Use shared access signatures (SAS) with minimal permissions
- Leverage managed identities for authentication
- Enable dead-lettering for reliable message processing
- Configure appropriate message TTL to prevent queue growth
- Use duplicate detection for idempotent operations
- Monitor queue/topic metrics for performance optimization
- Implement retry policies with exponential backoff
- Use sessions for ordered message processing

### SQL Server Security

**Security Features:**
- ✅ **Private endpoint** - Traffic stays within VNet
- ✅ **Service endpoint** - Optimized routing to SQL Server
- ✅ **Public network access disabled** - When private endpoint is enabled
- ✅ **Transparent Data Encryption (TDE)** - Automatic encryption at rest
- ✅ **Automated backups** - Point-in-time restore (7-35 days)
- ✅ **Geo-redundant backup** - Available for production environments
- ✅ **System-assigned managed identity** - For Azure RBAC integration
- ✅ **Microsoft Entra ID authentication** - Optional centralized identity management
- ✅ **SQL authentication** - With strong password requirements
- ✅ **TLS 1.2 minimum** - Secure data in transit
- ✅ **Diagnostic settings** - Comprehensive logging and monitoring
- ✅ **Advanced Threat Protection** - Can be enabled post-deployment

**Database Features:**
- ✅ **General Purpose tier** - Best price-performance for most workloads
- ✅ **Gen5 compute** - Latest generation hardware
- ✅ **Configurable vCores** - Scale from 2 to 80 vCores
- ✅ **Configurable storage** - Up to 4 TB per database
- ✅ **Zone redundancy** - High availability option
- ✅ **Azure Hybrid Benefit** - License portability for cost savings
- ✅ **Auto-pause/resume** - Available for serverless tier

**Best Practices:**
- Use Entra ID authentication instead of SQL authentication
- Enable private endpoints in production environments
- Implement proper firewall rules for allowed IP ranges
- Use managed identities for application connections
- Configure appropriate backup retention based on compliance needs
- Enable geo-replication for mission-critical databases
- Monitor DTU/vCore usage and adjust sizing accordingly
- Use Azure Hybrid Benefit to reduce costs if you have licenses
- Regularly review and audit database access patterns
- Enable Advanced Threat Protection for production workloads

### Application Gateway Security

**Security Features:**
- ✅ **Layer 7 load balancing** - HTTP/HTTPS traffic management
- ✅ **Web Application Firewall (WAF)** - OWASP rule set 3.2 protection
- ✅ **SSL/TLS termination** - Centralized certificate management
- ✅ **End-to-end encryption** - Optional backend HTTPS
- ✅ **Autoscaling** - Automatic capacity adjustment (0-125 units)
- ✅ **Zone redundancy** - Built-in high availability
- ✅ **Public IP** - Static Standard SKU with DDoS protection
- ✅ **User-Assigned Identity** - For AGIC integration
- ✅ **Health probes** - Automatic backend health monitoring
- ✅ **Custom error pages** - Branded error responses
- ✅ **URL-based routing** - Path and hostname routing
- ✅ **HTTP/2 support** - Modern protocol support

**WAF Protection:**
- Detection or Prevention mode
- OWASP Top 10 protection
- Bot protection
- Custom rules support
- Request body inspection
- File upload limits

**Best Practices:**
- Use WAF_v2 SKU for production environments
- Enable Prevention mode in production
- Configure custom health probes for backend services
- Use private backend pools when possible
- Enable HTTP/2 for better performance
- Monitor WAF logs for security insights
- Configure SSL policies for strong encryption
- Use custom domains with proper certificates

### AKS Security

**Security Features:**
- ✅ **System-assigned managed identity** - For Azure resource access
- ✅ **Azure CNI networking** - Pod-level network policies
- ✅ **Azure Network Policy** - Kubernetes network segmentation
- ✅ **AGIC addon** - Secure ingress via Application Gateway
- ✅ **Private cluster** - Optional API server private access
- ✅ **Azure RBAC** - Role-based access control
- ✅ **Microsoft Entra ID integration** - Centralized authentication
- ✅ **Azure Policy** - Compliance and governance
- ✅ **Secrets Store CSI Driver** - Key Vault integration (optional)
- ✅ **Node image upgrades** - Automatic security patching
- ✅ **Encryption at host** - Available for node disks
- ✅ **Azure Monitor** - Comprehensive logging and monitoring

**AGIC Benefits:**
- Native Kubernetes Ingress support
- Automatic Application Gateway configuration
- Zero-downtime deployments
- Traffic splitting for canary deployments
- SSL/TLS termination at gateway
- Centralized WAF protection
- Better cost optimization vs LoadBalancer services

**Best Practices:**
- Use Standard or Premium SKU for production
- Enable autoscaling for variable workloads
- Configure resource requests and limits for pods
- Use Azure CNI for better network integration
- Enable Azure Monitor for observability
- Implement pod security standards
- Use Microsoft Entra ID for cluster access
- Enable automatic upgrades with stable channel
- Configure node pools for different workload types
- Use AGIC for ingress instead of nginx or traefik
- Implement network policies for pod-to-pod traffic
- Use Azure Key Vault for secrets management

### API Management Security

**Security Features:**
- ✅ **VNet integration** - External or Internal mode
- ✅ **Service endpoints** - Optimized routing within VNet
- ✅ **TLS 1.2 minimum** - Older protocols disabled
- ✅ **System-assigned managed identity** - For Azure resource access
- ✅ **Subscription keys** - API access control
- ✅ **OAuth 2.0 / OpenID Connect** - Modern authentication
- ✅ **Client certificates** - Mutual TLS authentication
- ✅ **IP filtering** - Whitelist/blacklist IP addresses
- ✅ **Rate limiting** - Protect backends from overload
- ✅ **CORS policies** - Cross-origin request control
- ✅ **Request/response transformation** - Data masking and modification
- ✅ **Caching** - Reduce backend load
- ✅ **Azure Monitor integration** - Comprehensive logging
- ✅ **Application Insights** - APM and diagnostics
- ✅ **Custom domains** - Branded API endpoints

**Policy Capabilities:**
- Authentication policies (JWT validation, OAuth, certificates)
- Access restriction policies (IP filter, usage quotas, rate limits)
- Transformation policies (set headers, query params, request/response body)
- Caching policies (store responses, lookup cache)
- Cross-domain policies (CORS, JSONP)
- Error handling policies (retry, return-response)

**Best Practices:**
- Use Developer SKU for non-production environments only
- Use Standard or Premium SKU for production
- Enable Internal VNet mode for private APIs
- Use External mode when gateway needs internet access
- Implement rate limiting and quotas
- Use subscription keys for all APIs
- Enable OAuth 2.0 for user-facing APIs
- Use client certificates for backend authentication
- Configure custom domains with SSL certificates
- Enable Application Insights for monitoring
- Use named values for environment-specific config
- Implement proper API versioning strategy
- Use products to group and manage APIs
- Configure caching for frequently accessed data
- Monitor API usage and performance metrics
- Use policy fragments for reusable policies
- Implement proper error handling in policies
- Regular backup of APIM configuration

## 📊 Validation

### Validate Before Deployment

```powershell
# Validate development deployment
az deployment sub validate `
  --location eastus2 `
  --template-file main.bicep `
  --parameters main.dev.bicepparam

# Validate production deployment
az deployment sub validate `
  --location eastus2 `
  --template-file main.bicep `
  --parameters main.prod.bicepparam
```

### Check Deployment Status

```powershell
# List recent deployments
az deployment sub list --query "[].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" --output table

# Get specific deployment details
az deployment sub show --name "<deployment-name>"
```

## 🔍 Monitoring & Diagnostics

When `enableDiagnostics` is set to `true`, the following logs are collected:

- **NSG Flow Logs** - Network traffic patterns
- **VNet Diagnostics** - Virtual network metrics and logs
- **Resource Metrics** - Performance and health metrics

View logs in Azure Monitor Log Analytics:

```kusto
// Query NSG flow logs
AzureDiagnostics
| where ResourceType == "NETWORKSECURITYGROUPS"
| where TimeGenerated > ago(1h)
| project TimeGenerated, Resource, ruleName_s, direction_s, decision_s

// Query VNet diagnostics
AzureDiagnostics
| where ResourceType == "VIRTUALNETWORKS"
| where TimeGenerated > ago(1h)
```

## 📈 Outputs

The deployment provides the following outputs:

| Output | Description |
|--------|-------------|
| `resourceGroupId` | Resource Group resource ID |
| `resourceGroupName` | Resource Group name |
| `vnetId` | Virtual Network resource ID |
| `vnetName` | Virtual Network name |
| `vnetAddressPrefix` | VNet address space |
| `subnetId` | Subnet resource ID |
| `subnetName` | Subnet name |
| `nsgId` | Network Security Group resource ID |
| `nsgName` | NSG name |
| `cosmosDbAccountId` | Cosmos DB account resource ID |
| `cosmosDbAccountName` | Cosmos DB account name |
| `cosmosDbEndpoint` | Cosmos DB endpoint URL |
| `cosmosDbDatabaseId` | Cosmos DB database resource ID |
| `cosmosDbDatabaseName` | Cosmos DB database name |
| `serviceBusNamespaceId` | Service Bus namespace resource ID |
| `serviceBusNamespaceName` | Service Bus namespace name |
| `serviceBusEndpoint` | Service Bus endpoint URL |
| `serviceBusQueueNames` | Array of queue names |
| `serviceBusTopicNames` | Array of topic names |
| `sqlServerId` | SQL Server resource ID |
| `sqlServerName` | SQL Server name |
| `sqlServerFqdn` | SQL Server fully qualified domain name |
| `sqlDatabaseNames` | Array of database names |
| `sqlDatabaseIds` | Array of database resource IDs |
| `appGatewayId` | Application Gateway resource ID |
| `appGatewayName` | Application Gateway name |
| `appGatewayPublicIp` | Application Gateway public IP address |
| `appGatewayFqdn` | Application Gateway fully qualified domain name |
| `appGatewayIdentityId` | Application Gateway managed identity resource ID |
| `aksClusterId` | AKS cluster resource ID |
| `aksClusterName` | AKS cluster name |
| `aksClusterFqdn` | AKS cluster FQDN |
| `kubernetesVersion` | Kubernetes version deployed |
| `aksIdentityPrincipalId` | AKS managed identity principal ID |
| `aksNodeResourceGroup` | AKS node resource group name |
| `agicIdentityObjectId` | AGIC addon identity object ID |
| `agicIdentityClientId` | AGIC addon identity client ID |
| `apimId` | API Management service resource ID |
| `apimName` | API Management service name |
| `apimGatewayUrl` | API Management gateway URL |
| `apimDeveloperPortalUrl` | API Management developer portal URL |
| `apimManagementApiUrl` | API Management management API URL |
| `apimPortalUrl` | API Management portal URL |
| `apimIdentityPrincipalId` | API Management managed identity principal ID |
| `apimPublicIpAddresses` | API Management public IP addresses |
| `apimPrivateIpAddresses` | API Management private IP addresses |

### Retrieve Outputs

```powershell
az deployment sub show `
  --name "<deployment-name>" `
  --query "properties.outputs"
```

## 🧹 Cleanup

Remove all deployed resources:

```powershell
# Remove development environment
az group delete --name rg-webapp-dev-eus2-001 --yes --no-wait

# Remove production environment
az group delete --name rg-webapp-prod-eus2-001 --yes --no-wait
```

**Note**: Deleting the resource group will remove all resources including the Cosmos DB account and all its data. Ensure you have backups if needed.

**Warning**: Service Bus messages in queues and topics will be permanently deleted. Export important messages before cleanup.

## 🔧 Troubleshooting

### Common Issues

**Issue: Deployment fails with "Address space overlap"**
- Ensure VNet CIDR ranges don't overlap with existing VNets
- Check that subnet CIDR is within VNet address space

**Issue: "Invalid CIDR notation"**
- Verify CIDR format: `10.0.0.0/16` (not `10.0.0.0-10.0.255.255`)
- Ensure subnet prefix is larger (higher number) than VNet prefix

**Issue: "Log Analytics workspace not found"**
- Update `logAnalyticsWorkspaceId` in production parameters
- Ensure workspace exists in the subscription
- Verify you have read permissions on the workspace

**Issue: "Cosmos DB account name already exists"**
- Cosmos DB account names must be globally unique
- Modify the `workloadName` or `instanceNumber` parameter
- Check if the name is already taken in another subscription

**Issue: "Private endpoint deployment fails"**
- Ensure subnet exists before deploying Cosmos DB
- Verify private endpoint network policies are disabled
- Check NSG rules don't block private endpoint traffic

**Issue: "Serverless capacity mode not available"**
- Serverless is not available in all regions
- Deploy to supported regions (eastus, westus, northeurope, etc.)
- Check Azure documentation for current region availability

**Issue: "Free tier already in use"**
- Only one free tier Cosmos DB account per subscription
- Set `enableCosmosDbFreeTier = false`
- Use standard serverless mode instead

**Issue: "Service Bus namespace name already exists"**
- Service Bus namespace names must be globally unique
- Modify the `workloadName` or `instanceNumber` parameter
- Check if the name is already taken

**Issue: "Private endpoint not supported for Standard SKU"**
- Private endpoints require Premium SKU
- Upgrade: `serviceBusSku = 'Premium'`
- Or use service endpoints with Standard SKU

**Issue: "Zone redundancy not available"**
- Zone redundancy requires Premium SKU
- Available only in supported regions
- Check Azure documentation for region availability

**Issue: "Queue/Topic creation fails"**
- Verify queue/topic names are unique within namespace
- Check size limits based on SKU tier
- Ensure parameter values are within allowed ranges

**Issue: "SQL Server name already exists"**
- SQL Server names must be globally unique
- Modify the `workloadName` or `instanceNumber` parameter
- Check if the name is already taken in another subscription

**Issue: "SQL Server admin password does not meet requirements"**
- Password must be 8-128 characters long
- Must contain characters from three categories: uppercase, lowercase, numbers, special characters
- Provide password securely via command line or Key Vault

**Issue: "SQL Database deployment fails"**
- Verify SKU name is valid for the tier (e.g., GP_Gen5_2)
- Check max size is within tier limits
- Ensure vCore count matches SKU name
- Verify region supports the selected SKU

**Issue: "Cannot connect to SQL Server"**
- Verify private endpoint is properly configured
- Check NSG rules allow traffic on port 1433
- Ensure DNS resolution for private endpoint
- Verify firewall rules if using public access
- Check if public network access is disabled

**Issue: "Entra ID authentication fails"**
- Verify object ID is correct (use `az ad user show`)
- Ensure Entra admin is configured correctly
- Check user has appropriate SQL permissions
- Verify Entra ID integration is enabled

**Issue: "Application Gateway deployment fails"**
- Ensure Application Gateway subnet is dedicated (no other resources)
- Verify subnet CIDR is large enough (/24 or larger recommended)
- Check NSG rules allow Gateway Manager traffic (ports 65200-65535)
- Ensure subnet doesn't have delegation configured
- Verify Application Gateway name is globally unique

**Issue: "Application Gateway shows unhealthy backends"**
- Check backend health probe configuration
- Verify backend services are running and accessible
- Ensure NSG allows traffic from Application Gateway subnet
- Check backend HTTP settings match backend configuration
- Review Application Gateway logs for specific errors

**Issue: "AKS deployment fails"**
- Verify subnet has sufficient IP addresses for nodes and pods
- Ensure service CIDR doesn't overlap with VNet address space
- Check DNS service IP is within service CIDR range
- Verify Kubernetes version is supported in the region
- Ensure VM size is available in the region

**Issue: "AGIC addon fails to enable"**
- Ensure Application Gateway is deployed first
- Verify Application Gateway ID is correct
- Check Application Gateway is in the same region as AKS
- Ensure Application Gateway has user-assigned identity
- Review AKS deployment logs for specific errors

**Issue: "Cannot connect to AKS cluster"**
- Run `az aks get-credentials` to get kubeconfig
- Verify you have appropriate RBAC permissions
- Check if cluster is private (requires VNet connectivity)
- Ensure kubectl is installed and configured
- Verify firewall rules if using private cluster

**Issue: "AGIC not creating ingress resources"**
- Verify AGIC addon is enabled: `az aks show --query addonProfiles.ingressApplicationGateway`
- Check AGIC pod is running: `kubectl get pods -n kube-system | grep agic`
- Review AGIC logs: `kubectl logs -n kube-system -l app=ingress-appgw`
- Ensure ingress annotations are correct
- Verify Application Gateway backend pools are configured

**Issue: "API Management deployment is slow"**
- APIM deployment typically takes 30-45 minutes
- This is normal for VNet-integrated APIM instances
- Monitor deployment progress in Azure Portal
- Check activity log for any errors

**Issue: "Cannot access API Management gateway"**
- Verify VNet integration mode (External vs Internal)
- Check NSG rules allow traffic on ports 80 and 443
- Ensure DNS resolution is working correctly
- For Internal mode, verify VNet connectivity (VPN/ExpressRoute)
- Check APIM service is in "Online" state

**Issue: "API calls return 401 Unauthorized"**
- Verify subscription key is included in request header
- Check subscription is active and not expired
- Ensure subscription is linked to the correct product
- Review API requires subscription setting
- Verify OAuth token if using OAuth authentication

**Issue: "API Management portal is not accessible"**
- Check if developer portal is enabled
- Verify custom domain configuration if used
- Ensure APIM service is fully provisioned
- Check DNS records for custom domains
- Review NSG and firewall rules

**Issue: "Backend returns timeout errors"**
- Increase timeout in backend HTTP settings
- Check backend service is running and accessible
- Verify backend URL in APIM configuration
- Review backend firewall rules
- Check if backend accepts traffic from APIM subnet

### Validation Commands

```powershell
# Check resource group exists
az group show --name rg-webapp-dev-eus2-001

# Verify VNet configuration
az network vnet show --resource-group rg-webapp-dev-eus2-001 --name vnet-webapp-dev-eus2-001

# List NSG rules
az network nsg rule list --resource-group rg-webapp-dev-eus2-001 --nsg-name nsg-webapp-dev-eus2-001 --output table

# Check Cosmos DB account
az cosmosdb show --name cosmos-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# List Cosmos DB databases
az cosmosdb sql database list --account-name cosmos-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# List Cosmos DB containers
az cosmosdb sql container list --account-name cosmos-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --database-name appdb-dev

# Check private endpoint connection
az network private-endpoint show --name cosmos-webapp-dev-eus2-001-pe --resource-group rg-webapp-dev-eus2-001

# Check Service Bus namespace
az servicebus namespace show --name sb-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# List Service Bus queues
az servicebus queue list --namespace-name sb-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --output table

# List Service Bus topics
az servicebus topic list --namespace-name sb-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --output table

# Check queue details
az servicebus queue show --name orders --namespace-name sb-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# Check SQL Server
az sql server show --name sql-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# List SQL databases
az sql db list --server sql-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --output table

# Check database details
az sql db show --name CWDB --server sql-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# Check SQL Server firewall rules
az sql server firewall-rule list --server sql-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --output table

# Check SQL Server private endpoint
az network private-endpoint show --name sql-webapp-dev-eus2-001-pe --resource-group rg-webapp-dev-eus2-001

# Test SQL Server connectivity (requires sqlcmd or Azure Data Studio)
sqlcmd -S sql-webapp-dev-eus2-001.database.windows.net -U sqladmin -d CWDB

# Check database size and usage
az sql db show --name CWDB --server sql-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --query "{Name:name, Status:status, Size:maxSizeBytes, SKU:sku.name}"

# Check Application Gateway
az network application-gateway show --name appgw-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# List Application Gateway backend health
az network application-gateway show-backend-health --name appgw-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# Get Application Gateway public IP
az network public-ip show --name pip-appgw-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --query "{IP:ipAddress, FQDN:dnsSettings.fqdn}"

# Check AKS cluster
az aks show --name aks-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# Get AKS credentials
az aks get-credentials --name aks-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --overwrite-existing

# Check AKS node status
kubectl get nodes

# Verify AGIC addon is enabled
az aks show --name aks-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --query "addonProfiles.ingressApplicationGateway"

# Check AGIC pods
kubectl get pods -n kube-system -l app=ingress-appgw

# List AKS node pools
az aks nodepool list --cluster-name aks-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --output table

# Check AKS cluster autoscaler status
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml

# Check API Management service
az apim show --name apim-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001

# Test API Management gateway
curl https://apim-webapp-dev-eus2-001.azure-api.net/echo/resource

# List APIs in APIM
az apim api list --service-name apim-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --output table

# List products in APIM
az apim product list --service-name apim-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --output table

# Get APIM gateway URL
az apim show --name apim-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --query "gatewayUrl" -o tsv

# Check APIM network status
az apim show --name apim-webapp-dev-eus2-001 --resource-group rg-webapp-dev-eus2-001 --query "{VNetType:virtualNetworkType, IPs:publicIPAddresses}"

# Test Echo API (replace with your subscription key)
curl -H "Ocp-Apim-Subscription-Key: YOUR_SUBSCRIPTION_KEY" https://apim-webapp-dev-eus2-001.azure-api.net/echo/resource?param1=sample
```

## 📚 Additional Resources

- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/)
- [Azure Naming Conventions](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)
- [Azure Virtual Network Best Practices](https://docs.microsoft.com/en-us/azure/virtual-network/concepts-and-best-practices)
- [Network Security Best Practices](https://docs.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)
- [Azure Cosmos DB Documentation](https://docs.microsoft.com/en-us/azure/cosmos-db/)
- [Cosmos DB Serverless](https://docs.microsoft.com/en-us/azure/cosmos-db/serverless)
- [Cosmos DB Private Endpoints](https://docs.microsoft.com/en-us/azure/cosmos-db/how-to-configure-private-endpoints)
- [Cosmos DB Partitioning Best Practices](https://docs.microsoft.com/en-us/azure/cosmos-db/partitioning-overview)
- [Azure Service Bus Documentation](https://docs.microsoft.com/en-us/azure/service-bus-messaging/)
- [Service Bus Queues, Topics, and Subscriptions](https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-queues-topics-subscriptions)
- [Service Bus Best Practices](https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-performance-improvements)
- [Service Bus Premium Tier](https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-premium-messaging)
- [Azure SQL Database Documentation](https://docs.microsoft.com/en-us/azure/azure-sql/database/)
- [SQL Database DTU vs vCore](https://docs.microsoft.com/en-us/azure/azure-sql/database/service-tiers-vcore)
- [SQL Database Pricing Tiers](https://docs.microsoft.com/en-us/azure/azure-sql/database/service-tiers-general-purpose-business-critical)
- [SQL Database Security Best Practices](https://docs.microsoft.com/en-us/azure/azure-sql/database/security-best-practice)
- [SQL Database Private Endpoints](https://docs.microsoft.com/en-us/azure/azure-sql/database/private-endpoint-overview)
- [SQL Database Backup and Restore](https://docs.microsoft.com/en-us/azure/azure-sql/database/automated-backups-overview)
- [Microsoft Entra ID Authentication](https://docs.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview)
- [Azure Hybrid Benefit for SQL](https://docs.microsoft.com/en-us/azure/azure-sql/azure-hybrid-benefit)
- [Azure Application Gateway Documentation](https://docs.microsoft.com/en-us/azure/application-gateway/)
- [Application Gateway v2 Overview](https://docs.microsoft.com/en-us/azure/application-gateway/overview-v2)
- [Web Application Firewall (WAF)](https://docs.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)
- [Application Gateway Autoscaling](https://docs.microsoft.com/en-us/azure/application-gateway/application-gateway-autoscaling-zone-redundant)
- [Azure Kubernetes Service (AKS) Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Application Gateway Ingress Controller (AGIC)](https://docs.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview)
- [AGIC Annotations](https://azure.github.io/application-gateway-kubernetes-ingress/annotations/)
- [AKS Networking Concepts](https://docs.microsoft.com/en-us/azure/aks/concepts-network)
- [Azure CNI Networking](https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni)
- [AKS Cluster Autoscaler](https://docs.microsoft.com/en-us/azure/aks/cluster-autoscaler)
- [Azure API Management Documentation](https://docs.microsoft.com/en-us/azure/api-management/)
- [API Management Pricing Tiers](https://docs.microsoft.com/en-us/azure/api-management/api-management-features)
- [APIM VNet Integration](https://docs.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet)
- [APIM Internal VNet](https://docs.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet)
- [APIM Policies](https://docs.microsoft.com/en-us/azure/api-management/api-management-policies)
- [APIM Authentication](https://docs.microsoft.com/en-us/azure/api-management/api-management-howto-protect-backend-with-aad)
- [APIM Developer Portal](https://docs.microsoft.com/en-us/azure/api-management/api-management-howto-developer-portal)

## 📄 License

This project is provided as-is for educational and professional use.

## 👥 Contributing

To contribute improvements:

1. Follow Azure Bicep best practices
2. Maintain consistent naming conventions
3. Add appropriate documentation
4. Test deployments in development environment first
5. Update parameter files with sensible defaults

---

**Note**: Always review and customize security rules, address spaces, and tags before deploying to production environments.
