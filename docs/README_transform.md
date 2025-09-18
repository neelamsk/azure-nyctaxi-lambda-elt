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
SELECT 'err',      COUNT(*) FROM err.trip        WHERE ingest_date=@d;

-- Top reject reasons
SELECT reject_reason, COUNT(*) FROM err.trip WHERE ingest_date=@d GROUP BY reject_reason ORDER BY 2 DESC;

-- DQ sanity
SELECT COUNT(*) bad_time
FROM core.trip_clean
WHERE ingest_date=@d AND pickup_ts_utc>dropoff_ts_utc;
```

---

## Idempotency & Retries

- **Scope**: everything runs **per `ingest_date`**.  
- **Core**: `DELETE FROM core.trip_clean WHERE ingest_date=@ingest_date` before insert.  
- **Err**: `DELETE FROM err.trip WHERE ingest_date=@ingest_date` before insert.  
- Safe to retry a failed day without creating duplicates.

---

## Performance Notes

- **CTAS** for large inserts → better compression & parallelism
- **CCI** on `core.trip_clean` → fast scans/aggregations
- **ROUND_ROBIN** distribution (no good natural hash key in NYC Taxi)
- Keep slice sizes reasonable (daily folders); prefer append-style loads

---

## Data Quality (hard gates)

The pipeline **fails** if any of these are true for the slice:
- `core.trip_clean` rowcount = 0
- `pickup_ts_utc > dropoff_ts_utc`
- Negative `fare_amount` or `trip_distance_km`
- Null `pickup_ts_utc` or `dropoff_ts_utc`
- Duplicate rows after dedupe rule

Quarantined rows are written to `err.trip` with a reason.

---

## Security & Governance

- **Access**: Managed Identity + RBAC; no secrets in code
- **Lineage**: ADF → Synapse → (optional) Purview scans and lineage
- **PII**: NYC taxi sample has no direct PII; if adding sources with PII, tag columns and apply masking/policies

---

## Troubleshooting

- **DQ gate failed**: Open **CoreDQ_Gate** output; fix source (or mapping), rerun the date.  
- **`core + err > stg`**: Ensure quarantine step deletes the slice before insert; check `ref.payment_type_map` for duplicate *active* rows.  
- **Insert defaults failing**: Use `INSERT … SELECT` and set `SYSUTCDATETIME()` explicitly (Synapse DW rule).

---

## Roadmap / Modeling Notes

- Consider a deterministic **`trip_sk`** (SHA-256 of the dedupe columns) in **model** layer for easier joins and optional hash distribution.
- Add dimensions/facts (`mdl.*`) with conformed dimensions and a semantic layer (e.g., Power BI).

---

## Ownership & Runbook

- **Primary pipeline**: `pl_daily_nyctaxi` (has the schedule/alert)
- **On-call**: Data Engineering (update with owner)
- **How to re-run a day**: Debug `pl_daily_nyctaxi` with the date
- **Where to look**:
  - ADF **Monitor** → Pipeline runs & Activity runs
  - `SELECT TOP 50 * FROM ops.run_log ORDER BY started_at_utc DESC;`
  - `SELECT TOP 50 * FROM ops.run_metrics ORDER BY run_ts_utc DESC;`
  - `SELECT TOP 50 * FROM ops.dq_result ORDER BY created_at_utc DESC;`

---

## Changelog

- v1: Initial staging→core pipelines, idempotent slices, quarantine, DQ gates, metrics. Distribution set to **ROUND_ROBIN** for NYC Taxi.
