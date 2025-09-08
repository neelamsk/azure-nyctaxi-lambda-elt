#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <resourceGroup> <adfName> <ingest_date YYYY-MM-DD>"
  exit 1
fi

RG="$1"
ADF="$2"
DATE="$3"

az datafactory pipeline create-run \
  --resource-group "$RG" \
  --factory-name "$ADF" \
  --name "PL_Stage_NycTaxi" \
  --parameters "{\"ingest_date\":\"$DATE\"}" \
  -o table
