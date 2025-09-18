-- Basic data quality checks for a given ingest date.
-- Expect: DECLARE @ingest_date DATE = '2025-01-01';

-- 1) Row counts (stg vs core)
SELECT
  'row_count_stg'  AS check_name,
  (SELECT COUNT(*) FROM stg.trip  WHERE ingest_date = @ingest_date) AS cnt;

SELECT
  'row_count_core' AS check_name,
  (SELECT COUNT(*) FROM core.trip_clean WHERE ingest_date = @ingest_date) AS cnt;

-- 2) Null key checks (adjust keys as needed)
SELECT 'null_trip_id_in_core' AS check_name, COUNT(*) AS cnt
FROM core.trip_clean
WHERE ingest_date = @ingest_date AND trip_id IS NULL;

-- 3) Duplicate check by business key (adjust if not using trip_id)
SELECT 'dupe_trip_id_in_core' AS check_name, COUNT(*) AS dupes
FROM (
  SELECT trip_id
  FROM core.trip_clean
  WHERE ingest_date = @ingest_date AND trip_id IS NOT NULL
  GROUP BY trip_id
  HAVING COUNT(*) > 1
) d;

-- 4) Domain checks
SELECT 'negative_fare_in_core'   AS check_name, COUNT(*) AS cnt
FROM core.trip_clean
WHERE ingest_date = @ingest_date AND fare_amount < 0;

SELECT 'negative_distance_core'  AS check_name, COUNT(*) AS cnt
FROM core.trip_clean
WHERE ingest_date = @ingest_date AND trip_distance_km < 0;

SELECT 'bad_time_order_core'     AS check_name, COUNT(*) AS cnt
FROM core.trip_clean
WHERE ingest_date = @ingest_date
  AND pickup_ts_utc > dropoff_ts_utc;
