-- Build a cleaned "slice" for a specific ingest_date using CTAS.
-- Reruns: drop the slice table and rebuild.

-- Expect: DECLARE @ingest_date DATE = '2025-01-01';  -- ADF will parameterize this

IF OBJECT_ID('core.trip_clean_slice') IS NOT NULL
  DROP TABLE core.trip_clean_slice;

CREATE TABLE core.trip_clean_slice
WITH (
  DISTRIBUTION = HASH (trip_id),
  CLUSTERED COLUMNSTORE INDEX
)
AS
SELECT
  UPPER(NULLIF(LTRIM(RTRIM(s.vendor_id)), ''))                    AS vendor_code,
  TRY_CAST(s.trip_id AS BIGINT)                                   AS trip_id,

  TRY_CONVERT(DATETIME2, s.pickup_datetime)                       AS pickup_ts_utc,
  TRY_CONVERT(DATETIME2, s.dropoff_datetime)                      AS dropoff_ts_utc,

  CASE 
    WHEN TRY_CAST(s.trip_distance AS FLOAT) IS NULL THEN NULL
    ELSE ROUND(TRY_CAST(s.trip_distance AS FLOAT) * 1.609344, 3)
  END                                                             AS trip_distance_km,

  TRY_CAST(s.fare_amount AS DECIMAL(9,2))                         AS fare_amount,

  COALESCE(rp.payment_type_std,
           CASE
             WHEN TRY_CAST(s.payment_type AS INT) = 1 THEN 'CARD'
             WHEN TRY_CAST(s.payment_type AS INT) = 2 THEN 'CASH'
             WHEN TRY_CAST(s.payment_type AS INT) = 3 THEN 'NO_CHARGE'
             WHEN TRY_CAST(s.payment_type AS INT) = 4 THEN 'DISPUTE'
           END)                                                   AS payment_type,

  CASE 
    WHEN TRY_CONVERT(DATETIME2, s.pickup_datetime) IS NOT NULL
     AND (DATEPART(HOUR, TRY_CONVERT(DATETIME2, s.pickup_datetime)) BETWEEN 22 AND 23
          OR DATEPART(HOUR, TRY_CONVERT(DATETIME2, s.pickup_datetime)) BETWEEN 0 AND 5)
    THEN 1 ELSE 0
  END                                                             AS is_night_ride,

  s.ingest_date,
  s.source_file_name,
  s.loaded_at
FROM stg.trip AS s
LEFT JOIN ref.payment_type_map rp
  ON NULLIF(LTRIM(RTRIM(s.payment_type)), '') = rp.payment_type_src
WHERE s.ingest_date = @ingest_date
  AND TRY_CONVERT(DATETIME2, s.pickup_datetime) IS NOT NULL
  AND TRY_CONVERT(DATETIME2, s.dropoff_datetime) IS NOT NULL
  AND TRY_CONVERT(DATETIME2, s.pickup_datetime) <= TRY_CONVERT(DATETIME2, s.dropoff_datetime)
  AND TRY_CAST(s.fare_amount AS DECIMAL(9,2)) >= 0
  AND TRY_CAST(s.trip_distance AS FLOAT) >= 0;
