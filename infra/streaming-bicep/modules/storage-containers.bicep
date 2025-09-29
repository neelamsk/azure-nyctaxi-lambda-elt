@description('Storage account name')
param storageAccountName string

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' existing = {
  name: '${storageAccountName}/default'
}

@description('Container names to ensure')
param containerNames array = [
  'streaming-curated'
  'streaming-dlq'
]

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = [for c in containerNames: {
  name: '${storageAccountName}/default/${c}'
  // no properties needed; defaults are private access
}]
