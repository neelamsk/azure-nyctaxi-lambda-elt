#!/usr/bin/env bash
# Use AzCopy for fast uploads to ADLS Gen2 (DFS endpoint).
# Usage: ./azcopy_example.sh <storageAccount> <dataset> <ingest_date> <local_dir>
# Example: ./azcopy_example.sh eltazr2adls nyc_taxi 2024-06-01 ./data/june01/

set -euo pipefail


if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <storageAccount> <dataset> <ingest_date YYYY-MM-DD> <local_dir>"
  exit 1
fi

command -v azcopy >/dev/null || { echo "azcopy not found. Install it and run 'azcopy login' first."; exit 1; }

SA="$1"
DATASET="$2"
DATE="$3"
SRC_DIR="$4"

if ! [[ -d "$SRC_DIR" ]]; then
  echo "Local directory not found: $SRC_DIR"
  exit 1
fi

if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: ingest_date must be YYYY-MM-DD, got '$DATE'"
  exit 1
fi

DEST="https://${SA}.dfs.core.windows.net/raw/${DATASET}/ingest_date=${DATE}/"

echo "Copying $SRC_DIR -> $DEST"
echo "(If prompted, run: azcopy login)"
azcopy copy "${SRC_DIR}" "${DEST}" --recursive --overwrite=true

echo "Done. Verify with:"
echo "  az storage fs file list --account-name $SA --auth-mode login -f raw -p \"$DATASET/ingest_date=$DATE\" -o table"

