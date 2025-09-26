#!/usr/bin/env bash
set -euo pipefail

# Args (or use env vars if you prefer)
RG="${1:?resource group}"
ASA_JOB_NAME="${2:?asa job name}"
EH_NAMESPACE="${3:?event hub namespace}"     # e.g. nyctaxi-ehns
EH_NAME="${4:?event hub name}"               # e.g. trips
SA_NAME="${5:?storage account name}"         # e.g. nyctaxistreamsa001
CONTAINER="${6:-streaming}"                  # default container

API="2021-10-01-preview"
SUB_ID="$(az account show --query id -o tsv)"
JOB_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.StreamAnalytics/streamingjobs/${ASA_JOB_NAME}"
URI_BASE="https://management.azure.com${JOB_ID}"

# 1) Input (Event Hub, MSI auth). Use $Default or pass CONSUMER_GROUP env to override.
CG="${CONSUMER_GROUP:-\$Default}"   # literal "$Default" unless overridden
EH_FQDN="${EH_NAMESPACE}.servicebus.windows.net"

echo "Creating ASA input 'inEH' (Event Hub ${EH_NAMESPACE}/${EH_NAME}, CG=${CG})..."
az rest --method PUT \
  --uri "${URI_BASE}/inputs/inEH?api-version=${API}" \
  --headers Content-Type=application/json \
  --body @- <<JSON
{
  "properties": {
    "type": "Stream",
    "datasource": {
      "type": "Microsoft.ServiceBus/EventHub",
      "properties": {
        "fullyQualifiedNamespace": "${EH_FQDN}",
        "eventHubName": "${EH_NAME}",
        "consumerGroupName": "${CG}",
        "authenticationMode": "Msi"
      }
    },
    "serialization": {
      "type": "Json",
      "encoding": "UTF8"
    }
  }
}
JSON

# 2) Output (Blob, MSI auth) writing JSON lines
echo "Creating ASA output 'outBlob' (Storage ${SA_NAME}/${CONTAINER})..."
az rest --method PUT \
  --uri "${URI_BASE}/outputs/outBlob?api-version=${API}" \
  --headers Content-Type=application/json \
  --body @- <<JSON
{
  "properties": {
    "datasource": {
      "type": "Microsoft.Storage/Blob",
      "properties": {
        "storageAccounts": [
          { "accountName": "${SA_NAME}" }
        ],
        "container": "${CONTAINER}",
        "pathPattern": "date={date}/{time}",
        "dateFormat": "yyyy/MM/dd",
        "timeFormat": "HH",
        "authenticationMode": "Msi"
      }
    },
    "serialization": {
      "type": "Json",
      "encoding": "UTF8",
      "format": "LineSeparated"
    }
  }
}
JSON

# 3) Transformation/Query
# Minimal pass-through query: SELECT * INTO [outBlob] FROM [inEH]
echo "Creating ASA transformation..."
az rest --method PUT \
  --uri "${URI_BASE}/transformations/Transformation?api-version=${API}" \
  --headers Content-Type=application/json \
  --body @- <<JSON
{
  "properties": {
    "streamingUnits": 1,
    "query": "SELECT * INTO [outBlob] FROM [inEH]"
  }
}
JSON

# 4) Start the job
echo "Starting ASA job..."
az rest --method POST \
  --uri "${URI_BASE}/start?api-version=${API}" \
  --headers Content-Type=application/json \
  --body "{}"

# quick poll for state
for i in {1..20}; do
  state="$(az rest --method GET --uri "${URI_BASE}?api-version=${API}" --query properties.jobState -o tsv || echo "")"
  echo "ASA job state: ${state}"
  [[ "${state}" == "Running" || "${state}" == "Processing" ]] && break
  sleep 5
done

echo "ASA wiring complete."
