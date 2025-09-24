@description('Short prefix for names, e.g. nyctaxi')
param prefix string = 'nyctaxi'

@description('Azure region')
param location string = 'eastus2'

@description('Event Hub partitions')
param ehPartitions int = 4

@description('Late/OOO tolerance (seconds), e.g. 900 = 15 min')
param lateSeconds int = 900

// ---------- Names we reuse ----------
var ehnsName           = 'ehns-${prefix}'
var eventHubName       = 'eh-${prefix}-trip'
var consumerGroupName  = 'asa'

// ---------- Storage (ADLS Gen2) ----------
resource sa 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${prefix}stream'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: sa
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource bronze 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'bronze'
  parent: blobService
  properties: {}
}

resource silver 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'silver'
  parent: blobService
  properties: {}
}

resource gold 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'gold'
  parent: blobService
  properties: {}
}

resource quarantine 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'quarantine'
  parent: blobService
  properties: {}
}

// ---------- Event Hubs ----------
resource ehns 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: ehnsName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 4
  }
}

resource eh 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: eventHubName
  parent: ehns
  properties: {
    partitionCount: ehPartitions
    messageRetentionInDays: 7
  }
}

resource cgAsa 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = {
  name: consumerGroupName
  parent: eh
}

// ---------- Stream Analytics job ----------
resource asa 'Microsoft.StreamAnalytics/streamingjobs@2021-10-01-preview' = {
  name: 'asa-${prefix}-trip'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    jobType: 'Cloud'
    dataLocale: 'en-US'
    compatibilityLevel: '1.2'
    eventsOutOfOrderPolicy: 'Adjust'
    eventsOutOfOrderMaxDelayInSeconds: lateSeconds
    eventsLateArrivalMaxDelayInSeconds: lateSeconds
    outputErrorPolicy: 'Stop'
    contentStoragePolicy: 'SystemAccount'
  }
}

// ASA input (Event Hubs)
resource asaInput 'Microsoft.StreamAnalytics/streamingjobs/inputs@2021-10-01-preview' = {
  name: 'trip_in'
  parent: asa
  properties: {
    type: 'Stream'
    serialization: {
      type: 'Json'
      properties: {
        encoding: 'UTF8'
      }
    }
    datasource: {
      type: 'Microsoft.ServiceBus/EventHub'
      properties: {
        serviceBusNamespace: ehnsName
        eventHubName: eventHubName
        consumerGroupName: consumerGroupName
        authenticationMode: 'Msi'
      }
    }
    // Event time field (JSON path)
    eventTimestampPath: '$.pickup_ts'
  }
}

// ASA output: BRONZE (Blob JSON)
resource asaOutBronze 'Microsoft.StreamAnalytics/streamingjobs/outputs@2021-10-01-preview' = {
  name: 'bronze_out'
  parent: asa
  properties: {
    datasource: {
      type: 'Microsoft.Storage/Blob'
      properties: {
        storageAccounts: [
          { accountName: sa.name }
        ]
        container: 'bronze'
        pathPattern: '${prefix}/trip/ingest_date={date}/event_hour={time}'
        dateFormat: 'yyyy-MM-dd'
        timeFormat: 'HH'
        authenticationMode: 'Msi'
      }
    }
    serialization: {
      type: 'Json'
      properties: {
        encoding: 'UTF8'
        format: 'LineSeparated'
      }
    }
  }
}

// ASA output: SILVER (Blob JSON)
resource asaOutSilver 'Microsoft.StreamAnalytics/streamingjobs/outputs@2021-10-01-preview' = {
  name: 'silver_out'
  parent: asa
  properties: {
    datasource: {
      type: 'Microsoft.Storage/Blob'
      properties: {
        storageAccounts: [
          { accountName: sa.name }
        ]
        container: 'silver'
        pathPattern: '${prefix}/trip/loaded_date={date}'
        dateFormat: 'yyyy-MM-dd'
        timeFormat: 'HH'
        authenticationMode: 'Msi'
      }
    }
    serialization: {
      type: 'Json'
      properties: {
        encoding: 'UTF8'
        format: 'LineSeparated'
      }
    }
  }
}

// ASA transformation (query)
resource asaTransform 'Microsoft.StreamAnalytics/streamingjobs/transformations@2021-10-01-preview' = {
  name: 't1'
  parent: asa
  properties: {
    streamingUnits: 3
    query: '''
      -- Pass-through everything into BRONZE
      SELECT * INTO [bronze_out]
      FROM [trip_in]; 

      -- Minimal clean/projection into SILVER (refine later)
      SELECT
        CAST(input.event_id AS NVARCHAR(128)) AS event_id,
        CAST(input.pickup_ts AS datetime)     AS pickup_ts,
        CAST(input.dropoff_ts AS datetime)    AS dropoff_ts,
        CAST(input.pickup_zone AS NVARCHAR(64)) AS pickup_zone,
        CAST(input.vendor_id AS NVARCHAR(16)) AS vendor_id,
        CAST(input.payment_type AS NVARCHAR(16)) AS payment_type,
        TRY_CAST(input.fare_amount AS float)  AS fare_amount,
        TRY_CAST(input.trip_distance AS float) AS trip_distance
      INTO [silver_out]
      FROM [trip_in] input
      WHERE input.pickup_ts IS NOT NULL
        AND input.pickup_zone IS NOT NULL
        AND TRY_CAST(input.fare_amount AS float) > 0;
    '''
  }
}

// ---------- RBAC for ASA Managed Identity ----------
@description('Event Hubs Data Receiver role')
var roleEhDataReceiver = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975')

@description('Storage Blob Data Contributor role')
var roleBlobDataContributor = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource rbacEh 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eh.id, 'asa-mi-eh-read')
  scope: eh
  properties: {
    roleDefinitionId: roleEhDataReceiver
    principalId: asa.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource rbacSa 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sa.id, 'asa-mi-blob-contrib')
  scope: sa
  properties: {
    roleDefinitionId: roleBlobDataContributor
    principalId: asa.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
