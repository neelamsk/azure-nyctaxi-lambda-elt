@description('LAW resource ID')
param lawId string

@description('Existing resource names (same RG)')
param asaJobName string
param ehNamespaceName string
param storageAccountName string

// ===== Existing resources (no location/sku/kind needed)
resource asa 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' existing = {
  name: asaJobName
}

resource ehns 'Microsoft.EventHub/namespaces@2022-10-01-preview' existing = {
  name: ehNamespaceName
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' existing = {
  name: '${storageAccountName}/default'
}

// ===== Diagnostic settings

// ASA → LAW (all logs + metrics)
resource diagAsa 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-law'
  scope: asa
  properties: {
    workspaceId: lawId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// Event Hubs namespace → LAW (all logs + metrics)
resource diagEh 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-law'
  scope: ehns
  properties: {
    workspaceId: lawId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// Storage (BLOB SERVICE scope) → LAW
// Use the exact categories your tenant/region reports:
// Logs: StorageRead, StorageWrite, StorageDelete
// Metrics: Capacity, Transaction
resource diagStgBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-law'
  scope: blob
  properties: {
    workspaceId: lawId
    logs: [
      { category: 'StorageRead',  enabled: true }
      { category: 'StorageWrite', enabled: true }
      { category: 'StorageDelete', enabled: true }
    ]
    metrics: [
      { category: 'Capacity',    enabled: true }
      { category: 'Transaction', enabled: true }
    ]
  }
}
