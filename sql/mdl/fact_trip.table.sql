IF OBJECT_ID('mdl.fact_trip') IS NULL
BEGIN
  CREATE TABLE mdl.fact_trip
  (
    -- Degenerate, deterministic trip identifier (SHA-256 hex). High-cardinality; used for HASH distribution.
    trip_id             CHAR(64)    NOT NULL,

    -- Foreign keys (surrogate keys from dims)
    pickup_date_key     INT         NOT NULL,
    pickup_time_key     INT         NULL,
    pu_location_key     INT         NULL,
    do_location_key     INT         NULL,
    vendor_key          INT         NOT NULL,
    payment_type_key    INT         NOT NULL,
    rate_code_key       INT         NULL,
    flag_key            INT         NULL,

    -- Measures (additive)
    trip_distance_km    DECIMAL(9,3)  NULL,
    fare_amount         DECIMAL(10,2) NULL,
    tip_amount          DECIMAL(10,2) NULL,
    tolls_amount        DECIMAL(10,2) NULL,
    total_amount        DECIMAL(10,2) NULL,

    -- Lineage
    ingest_date         DATE          NOT NULL,
    source_file_name    VARCHAR(256)  NULL,
    loaded_at           DATETIME2     NULL
  )
  WITH (
    DISTRIBUTION = HASH (trip_id),
    CLUSTERED COLUMNSTORE INDEX
  );
END;
