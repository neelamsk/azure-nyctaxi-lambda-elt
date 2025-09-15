#!/usr/bin/env bash
# Upload local files (glob) to ADLS Gen2 landing:
#   raw/<dataset>/ingest_date=YYYY-MM-DD/<file>
# For each uploaded file, also writes a per-file manifest:
#   raw/<dataset>/ingest_date=YYYY-MM-DD/_INGESTION_<basename>.json
#
# Usage:
#   ./ingest/upload_raw.sh <dataset> <local_glob> [ingest_date=YYYY-MM-DD]
#
# Env:
#   AZURE_STORAGE_ACCOUNT (required)  e.g., eltazr3adls
#   AZURE_STORAGE_FILE_SYSTEM (opt)   defaults to "raw"
#
# Notes:
# - No overwrite: existing destination files are skipped (raw is immutable).
# - Requires: Azure CLI logged in to the correct subscription.

set -euo pipefail

usage() {
  cat <<EOF
Usage:
  $(basename "$0") <dataset> <local_glob> [ingest_date=YYYY-MM-DD]

Examples:
  $(basename "$0") nyctaxi_yellow "./data/yellow_tripdata_2020-01.parquet" 2020-01-31
  $(basename "$0") nyctaxi_yellow "./data/yellow_2020-*.parquet"            # defaults to UTC today

Env:
  AZURE_STORAGE_ACCOUNT        (required) your ADLS account name (e.g., eltazr3adls)
  AZURE_STORAGE_FILE_SYSTEM    (optional) container; default: raw
EOF
}

# ---- args & defaults
dataset="${1:-}"; [[ -z "${dataset}" ]] && usage && exit 1
glob_pat="${2:-}"; [[ -z "${glob_pat}" ]] && usage && exit 1
ingest_date="${3:-$(date -u +%F)}"

# Basic YYYY-MM-DD validation if provided
if ! [[ "${ingest_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: ingest_date must be YYYY-MM-DD, got '${ingest_date}'" >&2
  exit 1
fi

account="${AZURE_STORAGE_ACCOUNT:-}"
fs="${AZURE_STORAGE_FILE_SYSTEM:-raw}"

if [[ -z "${account}" ]]; then
  echo "ERROR: set AZURE_STORAGE_ACCOUNT (e.g., export AZURE_STORAGE_ACCOUNT=eltazr3adls)" >&2
  exit 1
fi

# Ensure Azure CLI has a context
if ! az account show >/dev/null 2>&1; then
  echo "INFO: not logged in; running 'az login'..." >&2
  az login >/dev/null
fi

# Expand glob safely
shopt -s nullglob
# shellcheck disable=SC2206 # we intentionally expand the glob into an array
files=( ${glob_pat} )
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files match glob: ${glob_pat}" >&2
  exit 1
fi

# Utilities
calc_md5() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$1"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "na"
  fi
}

run_id="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid || date +%s)"
ts_utc="$(date -u +%FT%TZ)"
who="$(whoami 2>/dev/null || echo unknown)"
dir_path="${dataset}/ingest_date=${ingest_date}"

echo "Account: ${account}  Container: ${fs}"
echo "Dataset: ${dataset}  Ingest date: ${ingest_date}"
echo "Files to upload: ${#files[@]}"
echo

uploaded=0
skipped=0
failed=0

for f in "${files[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "SKIP (not a regular file): ${f}"
    ((skipped++)) || true
    continue
  fi

  base="$(basename "$f")"
  dest_path="${dir_path}/${base}"
  manifest_path="${dir_path}/_INGESTION_${base}.json"

  # Idempotency: check existence
  exists=$(az storage fs file exists \
    --account-name "${account}" \
    --file-system "${fs}" \
    --path "${dest_path}" \
    --auth-mode login --query exists -o tsv 2>/dev/null || echo false)

  if [[ "${exists}" == "true" ]]; then
    echo "SKIP (exists): ${fs}/${dest_path}"
    ((skipped++)) || true
    continue
  fi

  bytes=$(wc -c < "$f" | tr -d ' ')
  md5=$(calc_md5 "$f")

  echo "PUT  ${fs}/${dest_path}  (${bytes} bytes)"
  if ! az storage fs file upload \
      --account-name "${account}" \
      --file-system "${fs}" \
      --path "${dest_path}" \
      --source "${f}" \
      --auth-mode login \
      --overwrite false 1>/dev/null; then
    echo "FAIL upload: ${fs}/${dest_path}"
    ((failed++)) || true
    continue
  fi

  # Write per-file manifest
  tmp_manifest="$(mktemp)"
  cat > "${tmp_manifest}" <<JSON
{
  "dataset": "${dataset}",
  "ingest_date": "${ingest_date}",
  "file": "${base}",
  "bytes": ${bytes},
  "md5": "${md5}",
  "source": "local-dev",
  "run_id": "${run_id}",
  "run_by": "${who}",
  "status": "SUCCEEDED",
  "ts_utc": "${ts_utc}"
}
JSON

  if ! az storage fs file upload \
      --account-name "${account}" \
      --file-system "${fs}" \
      --path "${manifest_path}" \
      --source "${tmp_manifest}" \
      --auth-mode login \
      --overwrite false 1>/dev/null; then
    echo "WARN: manifest write failed: ${fs}/${manifest_path}"
  fi
  rm -f "${tmp_manifest}"

  ((uploaded++)) || true
done

echo
echo "Summary: uploaded=${uploaded}  skipped=${skipped}  failed=${failed}"
echo "Verify (example):"
echo "  az storage fs file list --account-name ${account} --file-system ${fs} --path ${dir_path} --auth-mode login -o table"
