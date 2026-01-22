// =========================================
// VIRTUAL MACHINE MODULE - DEVOPS RUNNER
// =========================================
// This module creates:
// - Virtual Machine for DevOps pipeline runner
// - Network Interface with private IP
// - OS disk (managed)
// - Optional data disk
// - System-assigned managed identity
// - VM extensions for Azure DevOps agent
// Following Azure VM best practices
// =========================================

metadata description = 'Deploys Virtual Machine for DevOps pipeline runner'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =========================================
// PARAMETERS
// =========================================

@description('Name of the virtual machine')
@minLength(1)
@maxLength(64)
param vmName string

@description('Azure region for the VM')
param location string = resourceGroup().location

@description('VM size')
param vmSize string = 'Standard_D4s_v3'

@description('Operating system type')
@allowed([
  'Windows'
  'Linux'
])
param osType string = 'Linux'

@description('Admin username for the VM')
@minLength(1)
@maxLength(20)
param adminUsername string = 'azureuser'

@description('Admin password for the VM')
@secure()
@minLength(12)
@maxLength(123)
param adminPassword string

@description('SSH public key for Linux VMs')
param sshPublicKey string = ''

@description('Subnet resource ID for the VM')
param subnetId string

@description('Enable public IP address')
param enablePublicIp bool = false

@description('Tags to apply to all resources')
param tags object = {}

@description('OS disk size in GB')
@minValue(30)
@maxValue(4095)
param osDiskSizeGB int = 128

@description('OS disk storage account type')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
  'StandardSSD_ZRS'
  'Premium_ZRS'
])
param osDiskType string = 'Premium_LRS'

@description('Enable data disk')
param enableDataDisk bool = true

@description('Data disk size in GB')
@minValue(1)
@maxValue(32767)
param dataDiskSizeGB int = 256

@description('Data disk storage account type')
@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
  'StandardSSD_ZRS'
  'Premium_ZRS'
  'UltraSSD_LRS'
])
param dataDiskType string = 'Premium_LRS'

@description('Enable accelerated networking')
param enableAcceleratedNetworking bool = true

@description('Network Security Group ID for the NIC')
param networkSecurityGroupId string = ''

@description('Enable boot diagnostics')
param enableBootDiagnostics bool = true

@description('Time zone for Windows VMs')
param timeZone string = 'UTC'

@description('Enable automatic OS updates (Windows only)')
param enableAutomaticUpdates bool = true

@description('Azure DevOps organization URL')
param devOpsOrgUrl string = ''

@description('Azure DevOps PAT token')
@secure()
param devOpsPat string = ''

@description('Azure DevOps agent pool name')
param devOpsPoolName string = 'Default'

// =========================================
// VARIABLES
// =========================================

var nicName = 'nic-${vmName}'
var publicIpName = 'pip-${vmName}'
var osDiskName = '${vmName}-osdisk'
var dataDiskName = '${vmName}-datadisk'

// Linux image reference
var linuxImageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

// Windows image reference
var windowsImageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2022-datacenter-azure-edition'
  version: 'latest'
}

var imageReference = osType == 'Linux' ? linuxImageReference : windowsImageReference

// =========================================
// RESOURCES
// =========================================

// Public IP Address (optional)
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (enablePublicIp) {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

// Network Interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: enablePublicIp ? {
            id: publicIp.id
          } : null
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
    enableIPForwarding: false
    networkSecurityGroup: !empty(networkSecurityGroupId) ? {
      id: networkSecurityGroupId
    } : null
  }
}

// Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        name: osDiskName
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: 'Delete'
        caching: 'ReadWrite'
      }
      dataDisks: enableDataDisk ? [
        {
          name: dataDiskName
          lun: 0
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGB
          managedDisk: {
            storageAccountType: dataDiskType
          }
          deleteOption: 'Delete'
          caching: 'ReadWrite'
        }
      ] : []
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: osType == 'Windows' || empty(sshPublicKey) ? adminPassword : null
      linuxConfiguration: osType == 'Linux' ? {
        disablePasswordAuthentication: !empty(sshPublicKey)
        ssh: !empty(sshPublicKey) ? {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        } : null
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
        }
      } : null
      windowsConfiguration: osType == 'Windows' ? {
        enableAutomaticUpdates: enableAutomaticUpdates
        timeZone: timeZone
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
          enableHotpatching: false
        }
      } : null
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: enableBootDiagnostics
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

// Azure DevOps Agent Extension for Linux
resource devOpsAgentExtensionLinux 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (osType == 'Linux' && !empty(devOpsOrgUrl) && !empty(devOpsPat)) {
  parent: virtualMachine
  name: 'InstallAzureDevOpsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
    }
    protectedSettings: {
      commandToExecute: 'bash -c "curl -fsSL https://aka.ms/install-vsts-agent.sh | bash -s -- --url ${devOpsOrgUrl} --auth pat --token ${devOpsPat} --pool ${devOpsPoolName} --agent ${vmName} --replace --acceptTeeEula"'
    }
  }
}

// Azure DevOps Agent Extension for Windows
resource devOpsAgentExtensionWindows 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (osType == 'Windows' && !empty(devOpsOrgUrl) && !empty(devOpsPat)) {
  parent: virtualMachine
  name: 'InstallAzureDevOpsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "Invoke-WebRequest -Uri https://vstsagentpackage.azureedge.net/agent/3.236.1/vsts-agent-win-x64-3.236.1.zip -OutFile agent.zip; Expand-Archive -Path agent.zip -DestinationPath C:\\agent; cd C:\\agent; .\\config.cmd --unattended --url ${devOpsOrgUrl} --auth pat --token ${devOpsPat} --pool ${devOpsPoolName} --agent ${vmName} --replace --acceptTeeEula --runAsService"'
    }
  }
}

// =========================================
// OUTPUTS
// =========================================

@description('VM resource ID')
output vmId string = virtualMachine.id

@description('VM name')
output vmName string = virtualMachine.name

@description('VM managed identity principal ID')
output vmPrincipalId string = virtualMachine.identity.principalId

@description('Network interface ID')
output nicId string = networkInterface.id

@description('Private IP address')
output privateIpAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress

@description('Public IP address')
output publicIpAddress string = enablePublicIp ? publicIp.properties.ipAddress : ''
