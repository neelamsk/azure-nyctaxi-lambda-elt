DECLARE @d DATE = '@{pipeline().parameters.run_date}';

-- 1) Idempotent delete
DELETE FROM mdl.fact_trip WHERE ingest_date = @d;

-- 2) Prepare slices
WITH c AS (
  SELECT
    -- A unique, deterministic id for each core row in this slice
    ROW_NUMBER() OVER (
      ORDER BY
        source_file_name, loaded_at,
        vendor_code, pickup_ts_utc, dropoff_ts_utc,
        fare_amount, trip_distance_km, payment_type
    ) AS core_row_id,
    vendor_code,
    pickup_ts_utc,
    dropoff_ts_utc,
    trip_distance_km,
    fare_amount,
    payment_type,
    ingest_date,
    source_file_name,
    loaded_at
  FROM core.trip_clean
  WHERE ingest_date = @d
),
s AS (
  SELECT
    UPPER(LTRIM(RTRIM(CONVERT(VARCHAR(32), VendorID))))        AS vendor_code_nk,
    TRY_CONVERT(DATETIME2, tpep_pickup_datetime)                AS pickup_ts_utc,
    TRY_CONVERT(DATETIME2, tpep_dropoff_datetime)               AS dropoff_ts_utc,
    ROUND(TRY_CAST(trip_distance AS FLOAT) * 1.609344, 3)       AS trip_distance_km_stg,
    TRY_CAST(fare_amount AS DECIMAL(9,2))                       AS fare_amount_clean,
    CAST(RatecodeID AS VARCHAR(16))                             AS rate_code_nk,
    UPPER(LTRIM(RTRIM(store_and_fwd_flag)))                     AS flag_nk,
    CAST(PULocationID AS SMALLINT)                              AS pu_location_nk,
    CAST(DOLocationID AS SMALLINT)                              AS do_location_nk,
    TRY_CAST(tip_amount AS DECIMAL(10,2))                       AS tip_amount,
    TRY_CAST(tolls_amount AS DECIMAL(10,2))                     AS tolls_amount,
    TRY_CAST(total_amount AS DECIMAL(10,2))                     AS total_amount,
    ingest_date,
    source_file_name,
    loaded_at
  FROM stg.trip
  WHERE ingest_date = @d
),
j AS (
  -- LEFT JOIN so every core row survives even if no stg row matches
  SELECT
    c.*,
    s.rate_code_nk, s.flag_nk, s.pu_location_nk, s.do_location_nk,
    s.tip_amount, s.tolls_amount, s.total_amount,
    ROW_NUMBER() OVER (
      PARTITION BY c.core_row_id
      ORDER BY s.loaded_at DESC, s.source_file_name DESC
    ) AS rn
  FROM c
  LEFT JOIN s
    ON c.ingest_date      = s.ingest_date
   AND c.source_file_name = s.source_file_name
   AND c.pickup_ts_utc    = s.pickup_ts_utc
   AND c.dropoff_ts_utc   = s.dropoff_ts_utc
),
picked AS (
  SELECT * FROM j WHERE rn = 1
),
keyed AS (
  SELECT
    CONVERT(CHAR(64),
      HASHBYTES('SHA2_256', CONCAT(
        COALESCE(UPPER(LTRIM(RTRIM(vendor_code))),'') , '|',
        CONVERT(VARCHAR(23), pickup_ts_utc, 126)      , '|',
        CONVERT(VARCHAR(23), dropoff_ts_utc, 126)     , '|',
        CONVERT(VARCHAR(50), CAST(fare_amount AS DECIMAL(18,2))) , '|',
        CONVERT(VARCHAR(50), CAST(trip_distance_km AS DECIMAL(18,3))) , '|',
        COALESCE(UPPER(LTRIM(RTRIM(payment_type))),'')
      ))
    , 2) AS trip_id,

    (YEAR(pickup_ts_utc)*10000 + MONTH(pickup_ts_utc)*100 + DAY(pickup_ts_utc)) AS pickup_date_key,
    (DATEPART(HOUR, pickup_ts_utc) * 3600 +
     DATEPART(MINUTE, pickup_ts_utc) * 60 +
     DATEPART(SECOND, pickup_ts_utc)) AS pickup_time_key,

    COALESCE(v.vendor_key, -1)       AS vendor_key,
    COALESCE(p.payment_type_key, -1) AS payment_type_key,
    COALESCE(r.rate_code_key, -1)    AS rate_code_key,
    COALESCE(f.flag_key, -1)         AS flag_key,
    COALESCE(pu.location_key, -1)    AS pu_location_key,
    COALESCE(do_.location_key, -1)   AS do_location_key,

    trip_distance_km,
    fare_amount,
    tip_amount,
    tolls_amount,
    total_amount,
    ingest_date,
    source_file_name,
    loaded_at
  FROM picked x
  LEFT JOIN mdl.dim_vendor        v  ON v.vendor_code_nk   = UPPER(LTRIM(RTRIM(x.vendor_code)))
  LEFT JOIN mdl.dim_payment_type  p  ON p.payment_type_nk  = UPPER(LTRIM(RTRIM(x.payment_type)))
  LEFT JOIN mdl.dim_rate_code     r  ON r.rate_code_nk     = x.rate_code_nk
  LEFT JOIN mdl.dim_flag          f  ON f.flag_nk          = x.flag_nk
  LEFT JOIN mdl.dim_location      pu ON pu.location_id_nk  = x.pu_location_nk
  LEFT JOIN mdl.dim_location      do_ ON do_.location_id_nk = x.do_location_nk
)
INSERT INTO mdl.fact_trip
(
  trip_id,
  pickup_date_key, pickup_time_key,
  pu_location_key, do_location_key,
  vendor_key, payment_type_key, rate_code_key, flag_key,
  trip_distance_km, fare_amount, tip_amount, tolls_amount, total_amount,
  ingest_date, source_file_name, loaded_at
)
SELECT
  trip_id,
  pickup_date_key, pickup_time_key,
  pu_location_key, do_location_key,
  vendor_key, payment_type_key, rate_code_key, flag_key,
  trip_distance_km, fare_amount, tip_amount, tolls_amount, total_amount,
  ingest_date, source_file_name, loaded_at
FROM keyed;
