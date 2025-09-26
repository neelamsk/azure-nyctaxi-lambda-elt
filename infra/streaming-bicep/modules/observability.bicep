@description('Location for LAW')
param location string = resourceGroup().location

@description('Log Analytics workspace name')
param lawName string

@description('Retention in days')
param lawRetentionDays int = 30

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  properties: {
    retentionInDays: lawRetentionDays
    features: { legacy: 0, searchVersion: 1 }
  }
}

output lawId string = law.id
