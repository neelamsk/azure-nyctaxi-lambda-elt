# NYC Taxi – Streaming Producer (Python)

This is a tiny Python producer to push sample NYC taxi trip events into **Event Hubs** so your **Azure Stream Analytics (ASA)** job can write JSON lines to Blob Storage.

**Current flow**

```
Producer (this tool) → Event Hubs (nyctaxi-ehns/trips)
                     → ASA job (asa-nyctaxi-trip)
                     → Storage (nyctaxistreamsa001 / container: streaming)
```

## Prerequisites

- Python 3.9+ and `pip`
- Azure CLI (`az`) logged in with access to the subscription
- Event Hubs namespace and hub already deployed:
  - **Resource group**: `rg-nyctaxi-stream`
  - **Namespace**: `nyctaxi-ehns`
  - **Event Hub**: `trips`
- ASA job already created and wired with:
  - Input **`inEH`** (consumer group `$Default`)
  - Output **`outBlob`** (storage: `nyctaxistreamsa001`, container: `streaming`)
  - Transformation: `SELECT * INTO [outBlob] FROM [inEH]`
  - Job state: **Running** (or you can start it later)

## Setup

```bash
# from the repo root
python3 -m venv .venv
source .venv/bin/activate           # Windows: .venv\Scripts\activate
python3 -m pip install --upgrade pip
python3 -m pip install azure-eventhub
```

## Get a connection string

> The producer uses a **connection string** in `EH_CONN`.

### Option A (least privilege – recommended)

Create a **send-only** policy scoped to the Event Hub:

```bash
az eventhubs eventhub authorization-rule create \
  -g rg-nyctaxi-stream \
  --namespace-name nyctaxi-ehns \
  --eventhub-name trips \
  --name sendonly \
  --rights Send

CONN=$(az eventhubs eventhub authorization-rule keys list \
  -g rg-nyctaxi-stream \
  --namespace-name nyctaxi-ehns \
  --eventhub-name trips \
  --name sendonly \
  --query primaryConnectionString -o tsv)

export EH_CONN="${CONN}"             # already scoped to the hub
```

### Option B (quick & dirty – full rights on namespace)

> Note: `--namespace-name` is required; `-n` here would be interpreted as `--name` (the auth rule).

```bash
CONN=$(az eventhubs namespace authorization-rule keys list \
  -g rg-nyctaxi-stream \
  --namespace-name nyctaxi-ehns \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv)

export EH_CONN="${CONN};EntityPath=trips"   # append EntityPath when using namespace-level key
```

> Windows PowerShell:
> ```powershell
> $env:EH_CONN = "$CONN;EntityPath=trips"
> ```

*(Optional)* Verify you set it (redacts endpoint):
```bash
echo "$EH_CONN" | sed 's/Endpoint=.*/Endpoint=... (redacted)/'
```

## Run the producer

```bash
python3 tools/streaming/producer/send.py
```

It sends **5** JSON events and exits:

```
sent 5 events
```

## Verify data landed

List blobs in the **streaming** container of **nyctaxistreamsa001**:

```bash
KEY=$(az storage account keys list -g rg-nyctaxi-stream -n nyctaxistreamsa001 --query '[0].value' -o tsv)
az storage blob list --account-name nyctaxistreamsa001 --account-key "$KEY" -c streaming -o table
```

You should see files under a date/time pattern (e.g., `date=YYYY/MM/DD/HH=...`).

If nothing shows up, check the ASA job state:

```bash
SUB_ID=$(az account show --query id -o tsv)
JOB_URI="https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/rg-nyctaxi-stream/providers/Microsoft.StreamAnalytics/streamingjobs/asa-nyctaxi-trip?api-version=2021-10-01-preview"
az rest --method GET --uri "$JOB_URI" --query properties.jobState -o tsv
```

Expected: `Running` or `Processing`.

## What the events look like

Each event is a single JSON object, one per line written to blob:

```json
{
  "vendor_id": "CMT",
  "pickup_datetime": "2025-09-26T15:20:05.123Z",
  "dropoff_datetime": "2025-09-26T15:30:05.123Z",
  "passenger_count": 2,
  "trip_distance": 3.42,
  "fare_amount": 12.50,
  "tip_amount": 2.10,
  "total_amount": 14.60,
  "payment_type": "CRD",
  "rate_code_id": 1,
  "store_and_fwd_flag": "N"
}
```

> The schema is just for testing; adapt keys/types to your real inbound payload later.

## Troubleshooting

- **`The messaging entity '...trips' could not be found`**  
  The connection string is missing `EntityPath=trips` (when using namespace-level key) or points to the wrong hub.

- **`Claim is not valid` / `Unauthorized`**  
  The SAS policy lacks **Send** rights or is on the wrong scope.

- **No blobs appear**  
  - ASA job not running or input/output names don’t match (`inEH`, `outBlob`).
  - Network/IP restrictions on the storage account or Event Hubs.
  - Check job state with the command above.

- **Accidentally committed secrets**  
  Rotate the SAS key:
  ```bash
  az eventhubs eventhub authorization-rule keys renew \
    -g rg-nyctaxi-stream \
    --namespace-name nyctaxi-ehns \
    --eventhub-name trips \
    --name sendonly \
    --key PrimaryKey
  ```

## Security notes

- Prefer **event-hub–scoped** SAS policy with **Send** only.
- Do **not** commit `EH_CONN` to source control.
- Consider using GitHub Actions **secrets** if you later automate producers.

## Optional: where this goes next (Lambda context)

Right now ASA writes raw JSON lines to blob. Common next steps:

- **Micro-batch** those blobs into your **Synapse Dedicated SQL Pool** (`COPY INTO stg → DQ/core → model tables`), so BI keeps using the same modeled tables it already uses for batch.
- Or add a **second ASA output** to write **real-time aggregates** directly to serving tables for sub-minute dashboards, while batch keeps full history.

## File layout

```
tools/
  streaming/
    producer/
      send.py       # the producer (uses EH_CONN)
      README.md     # (this file)
```
