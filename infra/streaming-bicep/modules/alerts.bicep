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

// ASA output errors via KQL (logs), 5-min eval / 15-min window
resource asaErrorsKql 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${prefix}-asa-output-errors-kql'
  location: location
  properties: {
    displayName: 'ASA Output Errors (logs)'
    description: 'Alerts when ASA emits output errors in Execution logs'
    enabled: true
    scopes: [ lawId ]  // workspace-scoped rule
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    severity: 2
    condition: {
      allOf: [
        {
          query: '''
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.STREAMANALYTICS"
| where Category == "Execution"
| where Message has "OutputError"
'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    actions: {
      // IMPORTANT: array of STRING IDs (not objects)
      actionGroups: [
        ag.id
      ]
    }
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


resource stg5xx 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
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
        ag.id
        ]
    }
  }
}
