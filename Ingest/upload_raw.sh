
```bash
#!/usr/bin/env bash
# Upload files into ADLS Gen2 raw landing with partitioning by ingest_date.
# Usage: ./upload_raw.sh <storageAccount> <dataset> <ingest_date> <local_glob>
# Example: ./upload_raw.sh eltazr2adls nyc_taxi 2024-06-01 "./data/yellow_2024-06*.parquet"

set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <storageAccount> <dataset> <ingest_date YYYY-MM-DD> <local_glob>"
  exit 1
fi


SA="$1"
DATASET="$2"
DATE="$3"
GLOB="$4"
FS="raw"

# Basic validation for date format YYYY-MM-DD
if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: ingest_date must be YYYY-MM-DD, got '$DATE'"
  exit 1
fi

# Ensure logged in and filesystem exists
az account show >/dev/null
az storage fs create --account-name "$SA" --auth-mode login -n "$FS" >/dev/null

# Expand the glob safely
shopt -s nullglob
files=( $GLOB )
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files match glob: $GLOB"
  exit 1
fi

# All files matching the glob will be uploaded to the raw filesystem, partitioned by dataset and ingest_date.
# The script will exit if no files match the glob.

# Upload each file to the raw filesystem, partitioned by dataset and ingest_date.
for f in "${files[@]}"; do
  base="$(basename "$f")"
  dest="${DATASET}/ingest_date=${DATE}/${base}"
  echo "Uploading $f -> $FS/$dest"
  az storage fs file upload \
    --account-name "$SA" --auth-mode login \
    -f "$FS" -s "$f" -p "$dest" --overwrite=true >/dev/null
done

echo "Done. Verify with:"
echo "  az storage fs file list --account-name $SA --auth-mode login -f $FS -p \"$DATASET/ingest_date=$DATE\" -o table"

