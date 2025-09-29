-- Post-load statistics refresh for Modeling layer
-- Safe to run every slice; idempotent

DECLARE @d DATE = '@{pipeline().parameters.run_date}';

-- One-time stats (created if missing) on common filter/join columns
IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE object_id = OBJECT_ID('mdl.fact_trip') AND name = 'st_fact_trip_pickup_date_key')
  CREATE STATISTICS st_fact_trip_pickup_date_key ON mdl.fact_trip(pickup_date_key);

IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE object_id = OBJECT_ID('mdl.fact_trip') AND name = 'st_fact_trip_vendor_key')
  CREATE STATISTICS st_fact_trip_vendor_key ON mdl.fact_trip(vendor_key);

IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE object_id = OBJECT_ID('mdl.fact_trip') AND name = 'st_fact_trip_payment_type_key')
  CREATE STATISTICS st_fact_trip_payment_type_key ON mdl.fact_trip(payment_type_key);

IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE object_id = OBJECT_ID('mdl.fact_trip') AND name = 'st_fact_trip_pu_key')
  CREATE STATISTICS st_fact_trip_pu_key ON mdl.fact_trip(pu_location_key);

IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE object_id = OBJECT_ID('mdl.fact_trip') AND name = 'st_fact_trip_do_key')
  CREATE STATISTICS st_fact_trip_do_key ON mdl.fact_trip(do_location_key);

IF NOT EXISTS (SELECT 1 FROM sys.stats WHERE object_id = OBJECT_ID('mdl.fact_trip') AND name = 'st_fact_trip_ingest_date')
  CREATE STATISTICS st_fact_trip_ingest_date ON mdl.fact_trip(ingest_date);

-- Refresh stats after slice insert (keeps plans healthy)
UPDATE STATISTICS mdl.fact_trip;
-- Location is the only dim that can grow meaningfully day to day
UPDATE STATISTICS mdl.dim_location;

-- (Optional) if you expect frequent changes to other dims, uncomment:
-- UPDATE STATISTICS mdl.dim_vendor;
-- UPDATE STATISTICS mdl.dim_payment_type;
-- UPDATE STATISTICS mdl.dim_rate_code;
-- UPDATE STATISTICS mdl.dim_flag;
