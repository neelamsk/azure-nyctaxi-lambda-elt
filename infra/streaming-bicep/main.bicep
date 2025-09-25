@description('Globally-unique name for the Storage Account (3-24 lowercase letters and numbers).')
param storageAccountName string

@description('Event Hubs namespace name (unique within subscription + region).')
param eventHubNamespaceName string

@description('Event Hub (topic) name.')
param eventHubName string

@description('Number of partitions for the Event Hub.')
@minValue(1)
@maxValue(32)
param ehPartitions int = 2

@description('Optional tags applied to all resources.')
param tags object = {}

@description('PrincipalId (objectId) of the Stream Analytics job\'s system-assigned identity. If empty, RBAC assignments are skipped.')
param asaPrincipalId string = ''

var location = resourceGroup().location

// ---- Storage Account + Container ----
resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
  }
}

resource saBlob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: sa
  properties: {}
}

@description('Blob container for ASA outputs')
resource saContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'streaming'
  parent: saBlob
  properties: {
    publicAccess: 'None'
  }
}

// ---- Event Hubs Namespace + Hub ----
// (Type metadata may be missing in Bicep for this API => BCP081 warning; deploys fine.)
resource ehNs 'Microsoft.EventHub/namespaces@2022-10-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  tags: tags
}

resource eh 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01' = {
  name: eventHubName
  parent: ehNs
  properties: {
    messageRetentionInDays: 1
    partitionCount: ehPartitions
  }
}

// ---- RBAC for ASA managed identity (conditional on asaPrincipalId) ----
// Storage Blob Data Contributor
@description('Assigns ASA MI rights to write to Blob.')
resource raBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(asaPrincipalId)) {
  name: guid(sa.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', asaPrincipalId)
  scope: sa
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: asaPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Azure Event Hubs Data Receiver (ASA reads from EH)
@description('Assigns ASA MI rights to read from Event Hub.')
resource raEhRecv 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(asaPrincipalId)) {
  name: guid(eh.id, 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde', asaPrincipalId)
  scope: eh
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde') // Azure Event Hubs Data Receiver
    principalId: asaPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ---- Outputs ----
output storageAccountId string = sa.id
output eventHubId string = eh.id
output blobContainerUrl string = 'https://${storageAccountName}.blob.core.windows.net/${saContainer.name}'
