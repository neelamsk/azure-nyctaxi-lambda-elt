@description('Storage account name')
param storageAccountName string

@description('Days after last modification to move to Cool')
param coolAfterDays int = 14

@description('Days after last modification to delete (dev hygiene)')
param deleteAfterDays int = 90

@description('Blob name prefixes to match (container/prefix). Use trailing "/" for whole container.')
param prefixMatches array = [
  'streaming/'
  'streaming-curated/'
  'streaming-dlq/'
]

resource stg 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource policy 'Microsoft.Storage/storageAccounts/managementPolicies@2021-04-01' = {
  name: 'default'           // management policy resource name is 'default'
  parent: stg
  properties: {
    policy: {
      rules: [
        {
          name: 'streaming-dev-lifecycle'
          enabled: true
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: coolAfterDays
                }
                delete: {
                  daysAfterModificationGreaterThan: deleteAfterDays
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: prefixMatches
            }
          }
        }
      ]
    }
  }
}
