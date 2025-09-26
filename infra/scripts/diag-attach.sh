#!/usr/bin/env bash
set -euo pipefail

SUB="${SUB:-$(az account show --query id -o tsv)}"
RG="${RG:?}"
LAW_ID="${LAW_ID:?}"
ASA_JOB_ID="${ASA_JOB_ID:?}"           # /subscriptions/.../providers/Microsoft.StreamAnalytics/streamingjobs/asa-nyctaxi-trip
EHNS_ID="${EHNS_ID:?}"                 # .../providers/Microsoft.EventHub/namespaces/nyctaxi-ehns
STG_ID="${STG_ID:?}"                   # .../providers/Microsoft.Storage/storageAccounts/nyctaxistreamsa001

enable_diag () {
  local RID="$1"; local NAME="$2"
  echo "-> Diagnostics on $NAME"
  az monitor diagnostic-settings create \
    --resource "$RID" \
    --name to-law \
    --workspace "$LAW_ID" \
    --logs '[{"category":"OperationalLogs","enabled":true},{"category":"Execution","enabled":true},{"category":"Authoring","enabled":true},{"category":"ApplicationLogs","enabled":true},{"category":"Audit","enabled":true},{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true},{"category":"ArchiveLogs","enabled":true}]' \
    --metrics '[{"category":"AllMetrics","enabled":true}]' \
    >/dev/null || az monitor diagnostic-settings update --resource "$RID" --name to-law --workspace "$LAW_ID" --metrics '[{"category":"AllMetrics","enabled":true}]' >/dev/null
}

enable_diag "$ASA_JOB_ID" "ASA job"
enable_diag "$EHNS_ID"    "Event Hubs namespace"
enable_diag "$STG_ID"     "Storage account"
echo "Diagnostics wired."
