@description('LAW resource ID')
param lawId string

@description('Existing resource names (same RG)')
param asaJobName string
param ehNamespaceName string
param storageAccountName string

// mark as existing (no location/sku/kind needed)
resource asa 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' existing = {
  name: asaJobName
}

resource ehns 'Microsoft.EventHub/namespaces@2022-10-01-preview' existing = {
  name: ehNamespaceName
}

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

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

resource diagStg 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-law'
  scope: stg
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
