-- Idempotent load for a given ingest_date: wipe that partition, then insert deduped winners from the slice.

-- Expect: DECLARE @ingest_date DATE = '2025-01-01';

-- 1) Idempotent delete of existing partition
DELETE FROM core.trip_clean WHERE ingest_date = @ingest_date;

-- 2) Deterministic dedupe from slice
;WITH ranked AS (
  SELECT s.*,
         ROW_NUMBER() OVER (
           PARTITION BY s.trip_id   -- If trip_id is not reliable, replace with a compound natural key
           ORDER BY s.loaded_at DESC, s.source_file_name DESC
         ) AS rn
  FROM core.trip_clean_slice s
  WHERE s.ingest_date = @ingest_date
)
INSERT INTO core.trip_clean
(
  vendor_code, trip_id, pickup_ts_utc, dropoff_ts_utc,
  trip_distance_km, fare_amount, payment_type, is_night_ride,
  ingest_date, source_file_name, loaded_at
)
SELECT
  vendor_code, trip_id, pickup_ts_utc, dropoff_ts_utc,
  trip_distance_km, fare_amount, payment_type, is_night_ride,
  ingest_date, source_file_name, loaded_at
FROM ranked
WHERE rn = 1;

-- 3) Optional: drop the slice if you don’t want to keep it
-- DROP TABLE core.trip_clean_slice;

-- 4) Observability metrics
INSERT INTO ops.run_metrics (layer, table_name, ingest_date, rows_in, rows_out, rows_err, run_ts_utc)
SELECT
  'core', 'trip_clean', @ingest_date,
  (SELECT COUNT(*) FROM stg.trip WHERE ingest_date = @ingest_date),
  (SELECT COUNT(*) FROM core.trip_clean WHERE ingest_date = @ingest_date),
  (SELECT COUNT(*) FROM err.trip WHERE ingest_date = @ingest_date),
  SYSUTCDATETIME();
