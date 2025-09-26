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

resource ehDrop 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${prefix}-eh-incoming-drop'
  location: 'global'
  properties: {
    description: 'Event Hubs IncomingMessages == 0 for 15 min'
    severity: 3
    enabled: true
    scopes: [ ehNamespaceId ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
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

var asaErrorsKql = '''
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.STREAMANALYTICS"
| where Category == "Execution"
| where Message has "OutputError"
'''

resource asaOutputErrors 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${prefix}-asa-output-errors-kql'
  location: location
  kind: 'LogAlert'
  properties: {
    description: 'ASA output errors > 0'
    enabled: true
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [ lawId ] // LAW resource ID
    criteria: {
      allOf: [
        {
          query: asaErrorsKql
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      // If you ever get a type error here, switch to object form:
      // actionGroups: [ { actionGroupId: ag.id } ]
      actionGroups: [ ag.id ]
    }
  }
}

var stg5xxKql = '''
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where Category in ("StorageRead","StorageWrite")
| where toint(httpStatusCode_s) between (500 .. 599)
'''

resource stg5xx 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: '${prefix}-stg-5xx'
  location: location
  kind: 'LogAlert'
  properties: {
    description: 'Storage 5xx in 15m'
    enabled: true
    severity: 3
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [ lawId ]
    criteria: {
      allOf: [
        {
          query: stg5xxKql
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [ ag.id ]
    }
  }
}
