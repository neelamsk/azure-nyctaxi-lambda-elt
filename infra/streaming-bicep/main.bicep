targetScope = 'resourceGroup'

// ──────────────────────────────────────────────────────────────────────────────
// Parameters
// ──────────────────────────────────────────────────────────────────────────────

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Storage account name (must be globally unique, 3–24 lowercase letters/numbers).')
param storageAccountName string

@description('Event Hubs namespace name.')
param eventHubNamespaceName string

@description('Event Hub name for input.')
param eventHubName string

@description('Principal ID of the ASA job managed identity (provided by workflow step).')
param asaPrincipalId string

@description('Optional tags to apply to resources.')
param tags object = {}

// Optional tuning
@minValue(1)
@maxValue(7)
param eventHubRetentionDays int = 1

@minValue(1)
@maxValue(32)
param eventHubPartitions int = 2

// (Optional) If you want to reference the ASA job later, you can pass this.
// Not required for RBAC below, so it’s optional.
// param asaJobName string
// resource asa 'Microsoft.StreamAnalytics/streamingjobs@2020-03-01' existing = {
//   name: asaJobName
// }

// ──────────────────────────────────────────────────────────────────────────────
// Storage Account (for ASA outputs, checkpoints, etc.)
// ──────────────────────────────────────────────────────────────────────────────

resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    enableHttpsTrafficOnly: true
    isHnsEnabled: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    encryption: {
      services: {
        blob: { enabled: true }
        file: { enabled: true }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource saBlob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: '${sa.name}/default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

@description('Container used by ASA output')
resource saContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${sa.name}/default/asa-output'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    saBlob
  ]
}

// ──────────────────────────────────────────────────────────────────────────────
// Event Hubs
// ──────────────────────────────────────────────────────────────────────────────

resource ehNs 'Microsoft.EventHub/namespaces@2022-10-01' = {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    kafkaEnabled: true
    zoneRedundant: false
    disableLocalAuth: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource eh 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01' = {
  name: '${ehNs.name}/${eventHubName}'
  properties: {
    messageRetentionInDays: eventHubRetentionDays
    partitionCount: eventHubPartitions
    status: 'Active'
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// RBAC for ASA Managed Identity
// Note: RoleAssignment.name must be a GUID computable at start of deployment.
// We derive stable GUIDs from scope + a static salt + asaPrincipalId.
// ──────────────────────────────────────────────────────────────────────────────

@description('Allow ASA MI to read from Event Hub (Azure Event Hubs Data Receiver)')
resource rbacEh 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eh.id, 'asa-mi-eh-read', asaPrincipalId)
  scope: eh
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975') // Data Receiver
    principalId: asaPrincipalId
    principalType: 'ServicePrincipal'
  }
}

@description('Allow ASA MI to write blobs (Storage Blob Data Contributor)')
resource rbacSa 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sa.id, 'asa-mi-blob-contrib', asaPrincipalId)
  scope: sa
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Blob Data Contributor
    principalId: asaPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Outputs (optional)
// ──────────────────────────────────────────────────────────────────────────────

output storageAccountId string = sa.id
output storageContainerName string = 'asa-output'
output eventHubId string = eh.id
