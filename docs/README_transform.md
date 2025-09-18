# Transformation Layer (Staging → Core)

This doc explains how the **staging → core** transformation works, how to run/rerun it, and what quality/performance/security guarantees it provides.

---

## Purpose

Turn raw-ish **staging** rows into clean, typed, deduped **core** rows that are stable building blocks for modeling and BI. The layer:
- Enforces types (`TRY_CONVERT/TRY_CAST`)
- Normalizes units/codes (miles→km, payment type canonicalization)
- Removes junk (negative values, impossible timestamps)
- Deduplicates deterministically
- Preserves lineage (`ingest_date`, `source_file_name`, `loaded_at`)
- Emits metrics and DQ results

---

## Pipelines (ADF/Synapse)

- `pl_raw_to_stg_nyctaxi` — (existing) lands files into **stg.trip**
- `pl_stg_to_core_nyctaxi` — builds **core.trip_clean**, quarantines rejects, runs DQ, writes metrics
- `pl_daily_nyctaxi` — **orchestrator** (raw→stg → stg→core). ⬅️ add the schedule/trigger only here.

**Parameters**
- `dataset` (string) — default: `nyctaxi_yellow`
- `run_date` (string, `yyyy-MM-dd`) — the slice to process

---

## Data Flow

1) **Build slice (CTAS)**  
   `sql/core/11_trip_clean.slice_ctas.sql`  
   - Type, trim, normalize units/codes  
   - Filter obvious junk (pickup≤dropoff, non-negative amounts/distances)

2) **Quarantine rejects**  
   `sql/err/21_err_trip.capture.sql`  
   - Inserts bad rows into `err.trip` with a reason  
   - **Idempotent**: deletes `err.trip` for `ingest_date` before re-inserting

3) **Load core (idempotent + dedupe + metrics)**  
   `sql/core/12_trip_clean.dedupe_load.sql`  
   - Deletes the `ingest_date` slice from `core.trip_clean`  
   - Dedupes with a deterministic window function  
   - Writes `ops.run_metrics`

4) **Data Quality gate**  
   `sql/tests/40_data_quality.sql`  
   - Hard failures (`THROW`) on: zero rows, pickup>dropoff, negatives, null key timestamps, duplicates

5) **Run logging**  
   `ops.run_log` updated at start/success/failure

---

## Tables (quick)

- **stg.trip** — 1:1 mirror of source (minimal typing), idempotent per `ingest_date`
- **core.trip_clean** — cleaned, deduped trips  
  - Distribution: **ROUND_ROBIN**  
  - Index: **CCI (columnstore)**  
  - *Note:* `trip_id` is **unused** for NYC Taxi (left `NULL`); a deterministic `trip_sk` may be added in modeling.
- **err.trip** — quarantined rows with `reject_reason`, `raw_payload`
- **ref.payment_type_map** — `payment_type_src → payment_type_std`, exactly one active row per src
- **ops.run_log / ops.run_metrics / ops.dq_result** — observability

---

## Transform Rules (authoritative)

- **Typing & Nulls**: `TRY_CAST/TRY_CONVERT`, `NULLIF(LTRIM(RTRIM(x)),'')`
- **Units**: `trip_distance_km = ROUND(miles * 1.609344, 3)`
- **Codes**: left join to `ref.payment_type_map` with `is_active=1`
- **Dedupe (NYC Taxi)**:  
  Partition by **(vendor_code, pickup_ts_utc, dropoff_ts_utc, fare_amount, trip_distance_km, payment_type)**  
  Order by **(loaded_at DESC, source_file_name DESC)**; keep `rn=1`
- **Filters (hard)**: pickup≤dropoff, non-negative distance/fare, non-null pickup/dropoff

---

## How to Run

### Daily (or ad-hoc single day)
Use the orchestrator (recommended):
1. Open `pl_daily_nyctaxi` → **Debug**  
2. Set `run_date` (e.g., `2025-01-15`) → Run  
3. Monitor: **Monitor → Pipeline runs** (or query ops tables below)

### Layer-only rerun (core)
If staging is already loaded for that date:
1. Open `pl_stg_to_core_nyctaxi` → **Debug** with same `run_date`  
2. Core is **idempotent** per slice: it will delete+rebuild

### Backfill
Use a list of dates with a backfill pipeline (e.g., `pl_backfill_list`) or run the orchestrator in a loop externally. Same code path = safer.

---

## Quick Verification Queries

```sql
-- Replace YYYY-MM-DD
DECLARE @d DATE = 'YYYY-MM-DD';

-- Side-by-side counts
SELECT 'stg' src,  COUNT(*) FROM stg.trip        WHERE ingest_date=@d
UNION ALL
SELECT 'core',     COUNT(*) FROM core.trip_clean WHERE ingest_date=@d
UNION ALL
SELECT 'err',      COUNT(*) FROM err.*
