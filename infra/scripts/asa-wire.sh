#!/usr/bin/env bash
set -euo pipefail
# set -x  # (optional) uncomment for one-run debug

# Args
RG="${1:?resource group}"
ASA_JOB_NAME="${2:?asa job name}"
EH_NAMESPACE="${3:?event hub namespace}"     # e.g. nyctaxi-ehns
EH_NAME="${4:?event hub name}"               # e.g. trips
SA_NAME="${5:?storage account name}"         # e.g. nyctaxistreamsa001
CONTAINER="${6:-streaming}"                  # default container for raw passthrough

# API versions
API="2021-10-01-preview"    # inputs, transformation, job control
API_OUT="2020-03-01"        # outputs (stable)
HEADERS="Content-Type=application/json"

SUB_ID="$(az account show --query id -o tsv)"
JOB_ID="/subscriptions/${SUB_ID}/resourceGroups/${RG}/providers/Microsoft.StreamAnalytics/streamingjobs/${ASA_JOB_NAME}"
URI_BASE="https://management.azure.com${JOB_ID}"

# Helper: current job state
get_state () {
  az rest --method GET \
    --uri "${URI_BASE}?api-version=${API}" \
    --query properties.jobState -o tsv 2>/dev/null || echo ""
}

# 0) Stop the job if it's not in a writable state
STATE="$(get_state || true)"
if [[ -n "${STATE}" && "${STATE}" != "Created" && "${STATE}" != "Stopped" && "${STATE}" != "Failed" ]]; then
  echo "ASA job state is '${STATE}'. Stopping before updates..."
  az rest --method POST \
    --uri "${URI_BASE}/stop?api-version=${API}" \
    --headers "${HEADERS}" \
    -o none || true
  for i in {1..30}; do
    STATE="$(get_state)"
    echo "Waiting for stoppage... state=${STATE:-<unknown>} ($i)"
    [[ "${STATE}" == "Created" || "${STATE}" == "Stopped" || "${STATE}" == "Failed" || -z "${STATE}" ]] && break
    sleep 5
  done
fi

# 1) Input: Event Hub (MSI auth). Use $Default or override via CONSUMER_GROUP env
CG="${CONSUMER_GROUP:-\$Default}"   # literal "$Default" unless overridden

echo "Creating ASA input 'inEH' (Event Hub ${EH_NAMESPACE}/${EH_NAME}, CG=${CG})..."
az rest --method PUT \
  --uri "${URI_BASE}/inputs/inEH?api-version=${API}" \
  --headers "${HEADERS}" \
  --body @- <<JSON
{
  "properties": {
    "type": "Stream",
    "datasource": {
      "type": "Microsoft.EventHub/EventHub",
      "properties": {
        "serviceBusNamespace": "${EH_NAMESPACE}",
        "eventHubName": "${EH_NAME}",
        "consumerGroupName": "${CG}",
        "authenticationMode": "Msi"
      }
    },
    "serialization": {
      "type": "Json",
      "properties": { "encoding": "UTF8" }
    }
  }
}
JSON

# 2) Output: raw JSON lines to ${CONTAINER} (with date/hour partitioning)
echo "Creating ASA output 'outBlob' (Storage ${SA_NAME}/${CONTAINER})..."
az rest --method PUT \
  --uri "${URI_BASE}/outputs/outBlob?api-version=${API_OUT}" \
  --headers "${HEADERS}" \
  --body @- <<JSON
{
  "properties": {
    "datasource": {
      "type": "Microsoft.Storage/Blob",
      "properties": {
        "storageAccounts": [ { "accountName": "${SA_NAME}" } ],
        "container": "${CONTAINER}",
        "pathPattern": "date={date}/{time}",
        "dateFormat": "yyyy/MM/dd",
        "timeFormat": "HH",
        "authenticationMode": "Msi"
      }
    },
    "serialization": {
      "type": "Json",
      "properties": { "encoding": "UTF8", "format": "LineSeparated" }
    }
  }
}
JSON

# 3) Output: curated CSV to streaming-curated (MSI)
echo "Creating ASA output 'outCuratedCsv' (Storage ${SA_NAME}/streaming-curated)..."
az rest --method PUT \
  --uri "${URI_BASE}/outputs/outCuratedCsv?api-version=${API_OUT}" \
  --headers "${HEADERS}" \
  --body @- <<JSON
{
  "properties": {
    "datasource": {
      "type": "Microsoft.Storage/Blob",
      "properties": {
        "storageAccounts": [ { "accountName": "${SA_NAME}" } ],
        "container": "streaming-curated",
        "pathPattern": "date={date}/{time}",
        "dateFormat": "yyyy/MM/dd",
        "timeFormat": "HH",
        "authenticationMode": "Msi"
      }
    },
    "serialization": {
      "type": "Csv",
      "properties": { "fieldDelimiter": ",", "encoding": "UTF8" }
    }
  }
}
JSON

# 4) Output: DLQ JSON to streaming-dlq (MSI)
echo "Creating ASA output 'outDlqJson' (Storage ${SA_NAME}/streaming-dlq)..."
az rest --method PUT \
  --uri "${URI_BASE}/outputs/outDlqJson?api-version=${API_OUT}" \
  --headers "${HEADERS}" \
  --body @- <<JSON
{
  "properties": {
    "datasource": {
      "type": "Microsoft.Storage/Blob",
      "properties": {
        "storageAccounts": [ { "accountName": "${SA_NAME}" } ],
        "container": "streaming-dlq",
        "pathPattern": "date={date}/{time}",
        "dateFormat": "yyyy/MM/dd",
        "timeFormat": "HH",
        "authenticationMode": "Msi"
      }
    },
    "serialization": {
      "type": "Json",
      "properties": { "encoding": "UTF8", "format": "LineSeparated" }
    }
  }
}
JSON

# 5) Transformation/Query: parse → curated CSV, DLQ JSON, keep raw pass-through
QUERY=$(cat <<'SQL'
WITH parsed AS (
  SELECT
    CAST(GetRecordPropertyValue(input, 'schemaVersion') AS NVARCHAR(MAX)) AS schemaVersion,
    CAST(GetRecordPropertyValue(input, 'eventId') AS NVARCHAR(MAX))        AS eventId,
    CAST(GetRecordPropertyValue(input, 'tpepPickupDatetime') AS DATETIME)  AS tpepPickupDatetime,
    CAST(GetRecordPropertyValue(input, 'tpepDropoffDatetime') AS DATETIME) AS tpepDropoffDatetime,
    CAST(GetRecordPropertyValue(input, 'vendorId') AS NVARCHAR(MAX))        AS vendorId,
    CAST(GetRecordPropertyValue(input, 'passengerCount') AS BIGINT)        AS passengerCount,
    CAST(GetRecordPropertyValue(input, 'tripDistance') AS FLOAT)           AS tripDistance,
    CAST(GetRecordPropertyValue(input, 'puLocationId') AS BIGINT)          AS puLocationId,
    CAST(GetRecordPropertyValue(input, 'doLocationId') AS BIGINT)          AS doLocationId,
    CAST(GetRecordPropertyValue(input, 'fareAmount') AS FLOAT)             AS fareAmount,
    CAST(GetRecordPropertyValue(input, 'tipAmount') AS FLOAT)              AS tipAmount,
    CAST(GetRecordPropertyValue(input, 'tollsAmount') AS FLOAT)            AS tollsAmount,
    CAST(GetRecordPropertyValue(input, 'improvementSurcharge') AS FLOAT)   AS improvementSurcharge,
    CAST(GetRecordPropertyValue(input, 'mtaTax') AS FLOAT)                 AS mtaTax,
    CAST(GetRecordPropertyValue(input, 'extra') AS FLOAT)                  AS extra,
    CAST(GetRecordPropertyValue(input, 'totalAmount') AS FLOAT)            AS totalAmount,
    CAST(GetRecordPropertyValue(input, 'paymentType') AS BIGINT)           AS paymentType,
    CAST(GetRecordPropertyValue(input, 'source') AS NVARCHAR(MAX))          AS source,
    CAST(GetRecordPropertyValue(input, 'producerTs') AS DATETIME)          AS producerTs,
    System.Timestamp                                                       AS enqueuedTs
  FROM [inEH] AS input
),
enriched AS (
  SELECT
    *,
    DATEDIFF(minute, tpepPickupDatetime, tpepDropoffDatetime) AS durationMin,
    CASE WHEN eventId IS NULL OR tpepPickupDatetime IS NULL OR tpepDropoffDatetime IS NULL
         THEN 1 ELSE 0 END AS missingRequired,
    CASE WHEN tripDistance < 0 OR fareAmount < 0 OR totalAmount < 0
         THEN 1 ELSE 0 END AS negativeValues,
    CASE WHEN DATEDIFF(minute, tpepPickupDatetime, tpepDropoffDatetime) < 0
           OR DATEDIFF(minute, tpepPickupDatetime, tpepDropoffDatetime) > 480
         THEN 1 ELSE 0 END AS badDuration
  FROM parsed
)

-- 1) curated CSV (ordered columns)
SELECT
  schemaVersion, eventId, tpepPickupDatetime, tpepDropoffDatetime, vendorId,
  passengerCount, tripDistance, puLocationId, doLocationId,
  fareAmount, tipAmount, tollsAmount, improvementSurcharge, mtaTax, extra, totalAmount,
  paymentType, source, producerTs, enqueuedTs, durationMin
INTO [outCuratedCsv]
FROM enriched
WHERE missingRequired = 0 AND negativeValues = 0 AND badDuration = 0;

-- 2) rejects → DLQ (include a compact reason)
SELECT
  eventId,
  tpepPickupDatetime,
  tpepDropoffDatetime,
  vendorId,
  tripDistance,
  totalAmount,
  durationMin,
  CASE
    WHEN missingRequired = 1 THEN 'missing_required'
    WHEN negativeValues = 1 THEN 'negative_values'
    WHEN badDuration = 1 THEN 'bad_duration'
    ELSE 'unknown'
  END AS reason,
  enqueuedTs
INTO [outDlqJson]
FROM enriched
WHERE missingRequired = 1 OR negativeValues = 1 OR badDuration = 1;

-- 3) keep raw pass-through (unchanged)
SELECT * INTO [outBlob] FROM [inEH];
SQL
)

# Escape query for JSON
QUERY_ESCAPED="$(printf '%s' "$QUERY" | sed ':a;N;$!ba;s/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')"

echo "Creating ASA transformation (parse → curated/DLQ/raw)..."
az rest --method PUT \
  --uri "${URI_BASE}/transformations/Transformation?api-version=${API}" \
  --headers "${HEADERS}" \
  --body @- <<JSON
{
  "properties": {
    "streamingUnits": 1,
    "query": "${QUERY_ESCAPED}"
  }
}
JSON

# 6) Start the job
echo "Starting ASA job..."
az rest --method POST \
  --uri "${URI_BASE}/start?api-version=${API}" \
  --headers "${HEADERS}" \
  --body "{}"

# Poll for running state
for i in {1..20}; do
  state="$(get_state)"
  echo "ASA job state: ${state}"
  [[ "${state}" == "Running" || "${state}" == "Processing" ]] && break
  sleep 5
done

echo "ASA wiring complete."
