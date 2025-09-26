param location string = resourceGroup().location

@description('Action group name')
param agName string
@description('Email to notify')
param agEmail string

@description('Targets')
param asaJobId string
param ehNamespaceId string
param lawId string

@description('Alert name prefix (env-aware)')
param prefix string = 'nyctaxi-dev'

resource ag 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: agName
  location: 'global'
  properties: {
    groupShortName: take(replace(agName, '-', ''), 12)
    enabled: true
    emailReceivers: [
      {
        name: 'primary'
        emailAddress: agEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource asaErrors 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${prefix}-asa-output-errors'
  location: 'global'
  properties: {
    description: 'ASA OutputDataErrors > 0 in 5 min'
    severity: 2
    enabled: true
    scopes: [ asaJobId ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'OutputDataErrors'
          metricName: 'OutputDataErrors'
          metricNamespace: 'Microsoft.StreamAnalytics/streamingjobs'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          dimensions: []
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: ag.id
      }
    ]
  }
}

resource ehDrop 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${prefix}-eh-incoming-drop'
  location: 'global'
  properties: {
    description: 'Event Hubs IncomingMessages == 0 for 10 min'
    severity: 3
    enabled: true
    scopes: [ ehNamespaceId ]
    evaluationFrequency: 'PT5M'  // was PT2M (invalid)
    windowSize: 'PT15M'          // was PT10M (invalid)
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'IncomingMessagesZero'
          metricName: 'IncomingMessages'
          metricNamespace: 'Microsoft.EventHub/namespaces'
          operator: 'LessThan'
          threshold: 1
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
        }
      ]
    }
    actions: [
      {
        actionGroupId: ag.id
      }
    ]
  }
}


resource stg5xx 'Microsoft.Insights/scheduledQueryRules@2022-09-01-preview' = {
  name: '${prefix}-stg-5xx'
  location: location
  properties: {
    displayName: 'Storage 5xx in 15m'
    description: 'Alerts on any 5xx from Blob read/write in last 15 minutes'
    enabled: true
    scopes: [ lawId ] // LAW-scoped log alert
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    severity: 3
    condition: {
      allOf: [
        {
          query: '''
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where Category in ("StorageRead","StorageWrite")
| where toint(httpStatusCode_s) between (500 .. 599)
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    actions: {
      actionGroups: [
        { actionGroupId: ag.id }
      ]
    }
  }
}
