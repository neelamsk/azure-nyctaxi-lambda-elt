-- Capture rejects that fail basic domain checks into err.trip.
-- Expect: DECLARE @ingest_date DATE = '2025-01-01';

INSERT INTO err.trip (ingest_date, source_file_name, loaded_at, reject_reason, raw_payload)
SELECT
  s.ingest_date,
  s.source_file_name,
  s.loaded_at,
  CASE
    WHEN TRY_CAST(s.fare_amount AS DECIMAL(9,2)) < 0 THEN 'NEGATIVE_FARE'
    WHEN TRY_CAST(s.trip_distance AS FLOAT) < 0 THEN 'NEGATIVE_DISTANCE'
    WHEN TRY_CONVERT(DATETIME2, s.pickup_datetime) > TRY_CONVERT(DATETIME2, s.dropoff_datetime) THEN 'PICKUP_AFTER_DROPOFF'
    ELSE 'OTHER_BAD_VALUES'
  END,
  s._full_json   -- if you staged a raw JSON column; otherwise replace with a concatenation of columns
FROM stg.trip s
WHERE s.ingest_date = @ingest_date
  AND (
       TRY_CAST(s.fare_amount AS DECIMAL(9,2)) < 0 OR
       TRY_CAST(s.trip_distance AS FLOAT) < 0 OR
       TRY_CONVERT(DATETIME2, s.pickup_datetime) > TRY_CONVERT(DATETIME2, s.dropoff_datetime) OR
       TRY_CONVERT(DATETIME2, s.pickup_datetime) IS NULL OR
       TRY_CONVERT(DATETIME2, s.dropoff_datetime) IS NULL
  );
