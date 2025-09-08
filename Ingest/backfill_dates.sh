#!/usr/bin/env bash
# Trigger an ADF pipeline once per day in a date range (inclusive).
# Usage: ./backfill_dates.sh <rg> <adfName> <pipelineName> <start YYYY-MM-DD> <end YYYY-MM-DD> [--wait]
# Example: ./backfill_dates.sh eltazr2-rg eltazr2-adf PL_Ingest_NycTaxi 2024-06-01 2024-06-30 --wait

set -euo pipefail

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <resourceGroup> <dataFactoryName> <pipelineName> <start YYYY-MM-DD> <end YYYY-MM-DD> [--wait]"
  exit 1
fi

RG="$1"
ADF="$2"
PL="$3"
START="$4"
END="$5"
WAIT="${6:-}"


# Validate dates
for d in "$START" "$END"; do
  if ! [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: date must be YYYY-MM-DD, got '$d'"
    exit 1
  fi
done

# Portable next-day function 
next_day() {
python - "$1" <<'PY'
import sys, datetime as dt
d = dt.datetime.strptime(sys.argv[1], "%Y-%m-%d")
print((d + dt.timedelta(days=1)).strftime("%Y-%m-%d"))
PY
}



# Fire one run and optionally wait
run_once() {
  local d="$1"
  echo "Triggering $PL for ingest_date=$d"
  RUN_ID=$(az datafactory pipeline create-run \
    --resource-group "$RG" --factory-name "$ADF" \
    --name "$PL" --parameters "{\"ingest_date\":\"$d\"}" \
    --query runId -o tsv)

  if [[ "$WAIT" == "--wait" ]]; then
    echo "Waiting for run $RUN_ID ..."
    STATUS="InProgress"
    while true; do
      STATUS=$(az datafactory pipeline-run show \
        --resource-group "$RG" --factory-name "$ADF" \
        --run-id "$RUN_ID" --query status -o tsv)
      case "$STATUS" in
        Succeeded) echo "Run $RUN_ID: Succeeded"; break;;
        Failed|Canceled|Cancelled) echo "Run $RUN_ID: $STATUS"; exit 1;;
        *) sleep 15;;
      esac
    done
  fi
}


d="$START"
while true; do
  run_once "$d"
  [[ "$d" == "$END" ]] && break
  d="$(next_day "$d")"
done

echo "Backfill complete from $START to $END."
