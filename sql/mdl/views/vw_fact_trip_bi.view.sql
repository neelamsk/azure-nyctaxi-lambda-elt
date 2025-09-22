IF OBJECT_ID('mdl.vw_fact_trip_bi') IS NOT NULL
  DROP VIEW mdl.vw_fact_trip_bi;
GO

CREATE VIEW mdl.vw_fact_trip_bi
AS
SELECT
  -- Keys for slicing
  f.pickup_date_key,
  d.date_value       AS pickup_date,
  f.pickup_time_key,
  t.hh24             AS pickup_hour,
  t.is_night         AS is_night_ride,

  -- Conformed dimensions
  v.vendor_code_nk       AS vendor_code,
  p.payment_type_nk      AS payment_type,
  r.rate_code_nk         AS rate_code,
  flg.flag_nk            AS store_and_fwd_flag,

  -- Role-played locations
  pu.borough             AS pickup_borough,
  pu.zone                AS pickup_zone,
  do_.borough            AS dropoff_borough,
  do_.zone               AS dropoff_zone,

  -- Measures (base)
  f.trip_distance_km,
  f.fare_amount,
  f.tip_amount,
  f.tolls_amount,
  f.total_amount,

  -- Convenience calcs (for QA; BI model can re-define)
  CASE WHEN f.fare_amount > 0
       THEN CAST(f.tip_amount / f.fare_amount AS DECIMAL(18,6))
       ELSE NULL END      AS tip_pct,
  CASE WHEN f.trip_distance_km > 0
       THEN CAST(f.fare_amount / f.trip_distance_km AS DECIMAL(18,6))
       ELSE NULL END      AS fare_per_km,

  -- Lineage (optional for drill)
  f.ingest_date,
  f.source_file_name
FROM mdl.fact_trip AS f
JOIN mdl.dim_date        AS d   ON d.date_key      = f.pickup_date_key
LEFT JOIN mdl.dim_time   AS t   ON t.time_key      = f.pickup_time_key
LEFT JOIN mdl.dim_vendor AS v   ON v.vendor_key    = f.vendor_key
LEFT JOIN mdl.dim_payment_type AS p ON p.payment_type_key = f.payment_type_key
LEFT JOIN mdl.dim_rate_code    AS r ON r.rate_code_key    = f.rate_code_key
LEFT JOIN mdl.dim_flag         AS flg ON flg.flag_key     = f.flag_key
LEFT JOIN mdl.dim_location     AS pu  ON pu.location_key  = f.pu_location_key
LEFT JOIN mdl.dim_location     AS do_ ON do_.location_key = f.do_location_key;
GO
