# Data Dictionary

## Conventions
- **Timezone:** All timestamps in `core.*` are UTC.
- **Units:** Distances in kilometers; currency values left in source currency (unless noted).
- **Lineage columns:** `ingest_date`, `source_file_name`, `loaded_at` carry through from staging.
- **Distribution/Storage (Synapse):** Big tables use **CLUSTERED COLUMNSTORE INDEX**. Core is **ROUND_ROBIN** unless a good hash key exists.

---

## Schema: `stg`

### stg.trip
**Grain:** 1 row ≈ 1 raw trip record from source file.  
**Purpose:** Mirror of landed files with minimal typing; isolates ingest from transforms.

**Important columns**
- `VendorID` (smallint, nullable): Source vendor code as-is.
- `tpep_pickup_datetime` / `tpep_dropoff_datetime` (datetime2, nullable): Source timestamps as text/typed by ADF mapping.
- `passenger_count`, `PULocationID`, `DOLocationID` (smallint, nullable)
- `trip_distance` (decimal(9,3), nullable): Source distance (miles in NYC taxi).
- `payment_type` (smallint/string): Source payment code.
- `fare_amount`, `extra`, `mta_tax`, `tip_amount`, `tolls_amount`, `improvement_surcharge`, `total_amount`, `congestion_surcharge`, `airport_fee` (decimal(10,2), nullable)

**Lineage**
- `ingest_date` (date, not null)
- `source_file_name` (nvarchar, nullable)
- `loaded_at` (datetime2, nullable)

**Notes**
- Allows “weird” data (nulls, negatives); cleaning happens in `core`.
- Physical design: typically **HEAP** / **ROUND_ROBIN** for fast loads.

---

## Schema: `core`

### core.trip_clean
**Grain:** 1 row = 1 cleaned trip record (near-source entity).  
**Purpose:** Typed, deduped, canonicalized “building block” for downstream models/BI.  
**Distribution:** **ROUND_ROBIN** (no stable high-cardinality hash key in NYC taxi).  
**Index:** **CLUSTERED COLUMNSTORE INDEX**.

**Columns**
- `vendor_code` (varchar(32), null): Uppercased, trimmed vendor code from `VendorID`.
- `trip_id` (bigint, null): **Unused for NYC taxi**; kept for cross-dataset compatibility. Do not rely on it. May be replaced by a deterministic `trip_sk` in modeling.
- `pickup_ts_utc`, `dropoff_ts_utc` (datetime2, null): Normalized timestamps.
- `trip_distance_km` (decimal(9,3), null): Miles → kilometers (× 1.609344), rounded to 3 dp.
- `fare_amount` (decimal(9,2), null)
- `payment_type` (varchar(16), null): Canonical value via `ref.payment_type_map` (e.g., CARD/CASH/NO_CHARGE/DISPUTE).
- `is_night_ride` (bit, null): 22:00–05:59 based on pickup time.
- `ingest_date` (date, not null) — lineage
- `source_file_name` (varchar(256), null) — lineage
- `loaded_at` (datetime2, null) — lineage

**Transform rules**
- **Typing:** `TRY_CONVERT/TRY_CAST`; blanks trimmed to NULL.
- **Units:** distance miles→km.
- **Codes:** `payment_type` mapped via `ref.payment_type_map (is_active=1)`.
- **Deduplication:** Window over  
  `(vendor_code, pickup_ts_utc, dropoff_ts_utc, fare_amount, trip_distance_km, payment_type)`  
  ordered by `(loaded_at DESC, source_file_name DESC)`; keep `rn=1`.
- **Filters (hard):** drop rows where pickup>dropoff, negative fare/distance, or null pickup/dropoff.
- **Observability:** Rows in/out/err recorded in `ops.run_metrics` per `ingest_date`.

---

## Schema: `err`

### err.trip
**Grain:** 1 row = 1 rejected raw record (row-level quarantine).  
**Purpose:** Preserve visibility of rejected data and reason for fast triage.

**Columns**
- `ingest_date` (date, not null)
- `source_file_name` (varchar(256), null)
- `loaded_at` (datetime2, null)
- `reject_reason` (varchar(64), not null): `NEGATIVE_FARE | NEGATIVE_DISTANCE | NULL_TIME | PICKUP_AFTER_DROPOFF | OTHER_BAD_VALUES`
- `raw_payload` (nvarchar(max), null): Concise stitched text of the offending row.
- `recorded_at_utc` (datetime2, not null): Populated at insert time.

**Behavior**
- **Idempotent per slice:** The pipeline **deletes** `err.trip` for the `ingest_date` and re-inserts on reruns.

---

## Schema: `ref`

### ref.payment_type_map
**Purpose:** Canonical mapping from source payment codes to standardized values.

**Columns**
- `payment_type_src` (varchar(50), not null)
- `payment_type_std` (varchar(50), not null)
- `is_active` (bit, not null)
- `valid_from_utc` (datetime2, null)
- `valid_to_utc` (datetime2, null)

**Notes**
- Exactly **one active** row per `payment_type_src`.
- Update pattern: close old row (`is_active=0`, set `valid_to_utc`), insert new active row.

---

## Schema: `ops`

### ops.run_log
**Purpose:** One row per pipeline stage run (status & timing).

**Columns**
- `run_id` (nvarchar(64), not null), `stage` (nvarchar(32), not null): e.g., `raw_to_stg`, `stg_to_core`
- `dataset` (nvarchar(128), not null), `ingest_date` (date, not null)
- `status` (nvarchar(16), not null): `STARTED | SUCCEEDED | FAILED`
- `started_at_utc` (datetime2, not null), `finished_at_utc` (datetime2, null)
- `rows_copied` (bigint, null)

### ops.dq_result
**Purpose:** Per-check results for DQ at each stage.

**Columns**
- `run_id`, `stage`, `check_name`, `ingest_date`, `status` (`PASSED|FAILED|WARNING`)
- `actual_value`, `threshold_value`, `error_message`, `created_at_utc`

### ops.run_metrics
**Purpose:** Per-slice counts across layers.

**Columns**
- `layer` (`stg|core|mdl`), `table_name`, `ingest_date`
- `rows_in`, `rows_out`, `rows_err`
- `run_ts_utc`, `recorded_at_utc`

---
