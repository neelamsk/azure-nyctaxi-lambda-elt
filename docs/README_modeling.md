# Modeling (Core → Star) — NYC Taxi

> **TL;DR:** We build a conformed star over cleaned core data. Grain = **1 cleaned trip**. Dims are small & reusable, fact is columnstore and hash-distributed by a **deterministic `trip_id`**. Loads are **idempotent by date**, with a DQ gate and post-load stats.

```
              +----------------+         +-----------------+
              |  dim_vendor    |         | dim_payment_type|
              +--------+-------+         +---------+-------+
                       ^                           ^
                       |                           |
+---------+    +-------+-------+        +----------+----------+     +------------------+
| dim_date|    |  dim_location  |       |    dim_flag        |     |   dim_rate_code  |
+----+----+    +----+------+----+       +----------+----------+     +---------+--------+
     ^              ^      ^                      ^                        ^
     |              |      |                      |                        |
     |        +-----+------+-----+         +------+------------------------+
     |        |     mdl.fact_trip |<-------+
     |        +-------------------+
     |           trip_id (HASH dist)
     |
  (slices by pickup_date_key)
```

---

## 1) Star schema contract (what goes where)

**Fact grain:** 1 cleaned, completed trip.

**Dimensions (conformed):**
- `mdl.dim_date`: `date_key (YYYYMMDD)`, `date_value`, year/quarter/month/day, week, ISO year/week, `is_weekend`, `is_holiday`.
- `mdl.dim_time` *(optional — else fold into date)*: `time_key (0..86399)`, hour/min/sec, `is_night` (22:00–05:59).
- `mdl.dim_vendor`: SK + `vendor_code_nk`, name (optional), `active_flag`.
- `mdl.dim_payment_type`: SK + `payment_type_nk` (CARD/CASH/…).
- `mdl.dim_rate_code` *(optional now)*: SK + `rate_code_nk`.
- `mdl.dim_flag`: SK + `flag_nk` (store-and-forward or other flags).
- `mdl.dim_location`: SK + `location_id_nk`, `borough`, `zone`, `service_zone` (role-play Pickup/Dropoff).

**Fact: `mdl.fact_trip`**
- **Degenerate ID:** `trip_id` (SHA-256 hex over core dedupe columns).
- **FKs:** `pickup_date_key`, `pickup_time_key`, `pu_location_key`, `do_location_key`, `vendor_key`, `payment_type_key`, `rate_code_key?`, `flag_key?`.
- **Measures:** `trip_distance_km`, `fare_amount`, `tip_amount`, `tolls_amount`, `total_amount`.
- **Lineage:** `ingest_date`, `source_file_name`, `loaded_at`.

---

## 2) Physical design (Synapse Dedicated)

- **Fact:** `CLUSTERED COLUMNSTORE INDEX`, `DISTRIBUTION = HASH(trip_id)` (high cardinality, even spread).  
- **Dims:** `DISTRIBUTION = REPLICATE`, `HEAP`.  
- **Partitioning:** none to start (add monthly by `pickup_date_key` only if volumes require).  
- **Stats:** Post-load `UPDATE STATISTICS mdl.fact_trip` keeps plans sharp.

---

## 3) Keys & SCD policy

- **SKs everywhere**, `*_key` columns in dims, `*_nk` as natural keys.  
- **Unknowns:** `-1` row seeded for each dim (`sql/mdl/seed_unknowns.sql`).  
- **SCD:** Type 1 for all dims here (overwrite). Consider Type 2 only if `dim_location` metadata changes and you need “as was”.

---

## 4) Load pattern (idempotent, date-sliced)

**Pipeline:** `pl_core_to_mdl_nyctaxi` (called by the orchestrator).  
**Order:** LogStart → Upsert dims → Load fact → Post-load stats → Modeling DQ gate → LogSuccess/Failure.

- **Dim upserts (anti-join insert):**  
  - `10_dim_vendor.upsert.sql` ← `core.trip_clean.vendor_code`  
  - `11_dim_payment_type.upsert.sql` ← `core.trip_clean.payment_type`  
  - `12_dim_rate_code.upsert.sql` *(optional)* ← `stg.trip.RatecodeID`  
  - `13_dim_flag.upsert.sql` ← `stg.trip.store_and_fwd_flag`  
  - `14_dim_location.upsert.sql` ← `stg.trip.PU/DO LocationID`

- **Fact load:** `40_fact_trip.load.sql`  
  - Delete slice → insert from **core** LEFT JOIN **stg** via **lineage + timestamps**.  
  - Compute `trip_id` (SHA-256 hex).  
  - Lookup NK→SK in dims, `COALESCE` to `-1` for unknowns.

- **Post-load stats:** `45_postload_stats.sql`  
  - Create targeted stats (first run) and `UPDATE STATISTICS mdl.fact_trip`.

- **Modeling DQ gate:** `50_dq_modeling.sql`  
  - **Fail:** `rowcount_fact_eq_core`, `sum_fare_matches_core`.  
  - **Warn:** unknowns in payment/rate/flag (real-world blanks).

---

## 5) DQ rules (modeling)

| Check                        | Type     | Intent                                   |
|-----------------------------|----------|-------------------------------------------|
| rowcount_fact_eq_core       | FAIL     | No drop/dup vs core slice                 |
| sum_fare_matches_core       | FAIL     | Reconciliation on base fare               |
| unknown_vendor_eq_0         | PASS     | Vendors resolved                          |
| unknown_payment_eq_0        | WARNING  | Blanks allowed; count and track           |
| unknown_rate_eq_0           | WARNING  | Blanks allowed; count and track           |
| unknown_flag_eq_0           | WARNING  | Blanks allowed; count and track           |
| unknown_pu/do_eq_0          | PASS     | PU/DO exist for NYC yellow                |

All results are logged to `ops.dq_result` with `stage='core_to_mdl'` and the run’s `RunId`.

---

## 6) BI-friendly view

**File:** `sql/mdl/views/vw_fact_trip_bi.view.sql`  
**Purpose:** Role-play locations (PU/DO), surface conformed attributes, expose base measures; friendly for BI.

Key columns: `pickup_date`, `pickup_hour`, `vendor_code`, `payment_type`, `rate_code`, `store_and_fwd_flag`, `pickup_borough/zone`, `dropoff_borough/zone`, measures + convenience calcs (`tip_pct`, `fare_per_km`).

---

## 7) Measures (authoritative definitions)

> Measures are defined over the star (fact + dims). Use these names consistently in BI.

- **Trips**  
  *Definition:* Count of trips  
  *SQL:* `COUNT_BIG(*)` over `mdl.fact_trip` (or `COUNT(DISTINCT trip_id)` if you need uniqueness by trip id)  
  *BI note:* Use `COUNTROWS` on the fact table.

- **Total Fare**  
  *Definition:* Sum of `fare_amount`  
  *SQL:* `SUM(fare_amount)`  
  *Notes:* Base currency is source currency; one row = one cleaned trip.

- **Tip %**  
  *Definition:* Ratio of tips to fare  
  *SQL:* `CASE WHEN SUM(fare_amount) > 0 THEN SUM(tip_amount) / SUM(fare_amount) END`  
  *BI note:* Use a safe divide (`DIVIDE([Total Tip],[Total Fare])`).

- **Avg Fare per Trip**  
  *Definition:* Average fare per completed trip  
  *SQL:* `SUM(fare_amount) / NULLIF(COUNT_BIG(*),0)`  
  *BI note:* Prefer `DIVIDE([Total Fare],[Trips])`.

- **Avg Fare per km**  
  *Definition:* Fare per kilometer  
  *SQL:* `SUM(fare_amount) / NULLIF(SUM(trip_distance_km),0)`  
  *BI note:* Same definition; avoid row-level average of per-row ratios.

---

## 8) Ops: reruns, monitoring, backfill

**Rerun a date:** trigger orchestrator `pl_daily_nyctaxi` with `run_date=YYYY-MM-DD` (end-to-end).  
**Where to look when red:** `ops.run_log`, `ops.dq_result` (stage=`core_to_mdl`).  
**Backfill:** list of dates in backfill pipeline, calling the orchestrator (keeps all layers aligned).

Example checks:
```sql
DECLARE @d DATE='YYYY-MM-DD';
SELECT COUNT(*) FROM mdl.fact_trip WHERE ingest_date=@d;
SELECT check_name,status,actual_value FROM ops.dq_result WHERE stage='core_to_mdl' AND ingest_date=@d ORDER BY created_at_utc;
```

---

## 9) Files (this layer)

```
sql/mdl/
  00_schema.sql
  dim_date.table.sql
  dim_time.table.sql
  dim_vendor.table.sql
  dim_payment_type.table.sql
  dim_rate_code.table.sql
  dim_flag.table.sql
  dim_location.table.sql
  fact_trip.table.sql
  seed_unknowns.sql

sql/mdl/load/
  10_dim_vendor.upsert.sql
  11_dim_payment_type.upsert.sql
  12_dim_rate_code.upsert.sql
  13_dim_flag.upsert.sql
  14_dim_location.upsert.sql
  40_fact_trip.load.sql
  45_postload_stats.sql
  50_dq_modeling.sql

sql/mdl/views/
  vw_fact_trip_bi.view.sql
```

---

## 10) Sign-off checklist

- ✅ A full day runs green: `rowcount_fact_eq_core` + `sum_fare_matches_core` **PASS**.  
- ✅ Unknowns are **WARNINGS** only (or modeled as explicit `'UNKNOWN'` NK members).  
- ✅ BI can filter/slice by date/vendor/payment/borough quickly.  
- ✅ Stats refreshed post-load.  
- ✅ Docs updated here and in main README.
