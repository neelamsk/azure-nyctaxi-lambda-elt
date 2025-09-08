-- One-time: create staging schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
    EXEC ('CREATE SCHEMA stg');

-- Drop/recreate if iterating during dev
IF OBJECT_ID('stg.trip') IS NOT NULL
    DROP TABLE stg.trip;

CREATE TABLE stg.trip
(
    -- Source columns (adjust to your Parquet schema; sample for Yellow Taxi)
    vendor_id                   VARCHAR(10)      NULL,
    tpep_pickup_datetime        DATETIME2(3)     NULL,
    tpep_dropoff_datetime       DATETIME2(3)     NULL,
    passenger_count             INT              NULL,
    trip_distance               DECIMAL(18,3)    NULL,
    ratecodeid                  INT              NULL,
    store_and_fwd_flag          CHAR(1)          NULL,
    pu_location_id              INT              NULL,
    do_location_id              INT              NULL,
    payment_type                INT              NULL,
    fare_amount                 DECIMAL(18,2)    NULL,
    extra                       DECIMAL(18,2)    NULL,
    mta_tax                     DECIMAL(18,2)    NULL,
    tip_amount                  DECIMAL(18,2)    NULL,
    tolls_amount                DECIMAL(18,2)    NULL,
    improvement_surcharge       DECIMAL(18,2)    NULL,
    total_amount                DECIMAL(18,2)    NULL,
    congestion_surcharge        DECIMAL(18,2)    NULL,
    airport_fee                 DECIMAL(18,2)    NULL,

    -- Technical columns
    ingest_date                 DATE             NOT NULL,
    source_file_name            NVARCHAR(400)    NOT NULL,
    loaded_at                   DATETIME2(3)     NOT NULL
)
WITH
(
    DISTRIBUTION = ROUND_ROBIN,
    HEAP
);
