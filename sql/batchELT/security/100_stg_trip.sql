-- Make sure the schema exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA stg');
GO

-- Create table if it doesn't exist (fast-load shape)
IF OBJECT_ID(N'stg.trip') IS NULL
BEGIN
  CREATE TABLE stg.trip
  (
    -- Source columns (keep nullable in staging)
    VendorID               SMALLINT      NULL,
    tpep_pickup_datetime   DATETIME2(0)  NULL,
    tpep_dropoff_datetime  DATETIME2(0)  NULL,
    passenger_count        SMALLINT      NULL,
    trip_distance          DECIMAL(9,3)  NULL,
    RatecodeID             SMALLINT      NULL,
    store_and_fwd_flag     CHAR(1)       NULL,
    PULocationID           SMALLINT      NULL,
    DOLocationID           SMALLINT      NULL,
    payment_type           SMALLINT      NULL,
    fare_amount            DECIMAL(10,2) NULL,
    extra                  DECIMAL(10,2) NULL,
    mta_tax                DECIMAL(10,2) NULL,
    tip_amount             DECIMAL(10,2) NULL,
    tolls_amount           DECIMAL(10,2) NULL,
    improvement_surcharge  DECIMAL(10,2) NULL,
    total_amount           DECIMAL(10,2) NULL,
    congestion_surcharge   DECIMAL(10,2) NULL,
    airport_fee            DECIMAL(10,2) NULL,

    -- Audit columns (filled by ADF sink "Additional columns")
    ingest_date            DATE          NOT NULL,
    source_file_name       NVARCHAR(512) NOT NULL,
    loaded_at              DATETIME2(3)  NOT NULL
  )
  WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
END
ELSE
BEGIN
  -- Helper: add a column if it doesn't exist
  -- (repeat pattern for each column)
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'VendorID')
    ALTER TABLE stg.trip ADD VendorID SMALLINT NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'tpep_pickup_datetime')
    ALTER TABLE stg.trip ADD tpep_pickup_datetime DATETIME2(0) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'tpep_dropoff_datetime')
    ALTER TABLE stg.trip ADD tpep_dropoff_datetime DATETIME2(0) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'passenger_count')
    ALTER TABLE stg.trip ADD passenger_count SMALLINT NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'trip_distance')
    ALTER TABLE stg.trip ADD trip_distance DECIMAL(9,3) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'RatecodeID')
    ALTER TABLE stg.trip ADD RatecodeID SMALLINT NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'store_and_fwd_flag')
    ALTER TABLE stg.trip ADD store_and_fwd_flag CHAR(1) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'PULocationID')
    ALTER TABLE stg.trip ADD PULocationID SMALLINT NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'DOLocationID')
    ALTER TABLE stg.trip ADD DOLocationID SMALLINT NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'payment_type')
    ALTER TABLE stg.trip ADD payment_type SMALLINT NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'fare_amount')
    ALTER TABLE stg.trip ADD fare_amount DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'extra')
    ALTER TABLE stg.trip ADD extra DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'mta_tax')
    ALTER TABLE stg.trip ADD mta_tax DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'tip_amount')
    ALTER TABLE stg.trip ADD tip_amount DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'tolls_amount')
    ALTER TABLE stg.trip ADD tolls_amount DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'improvement_surcharge')
    ALTER TABLE stg.trip ADD improvement_surcharge DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'total_amount')
    ALTER TABLE stg.trip ADD total_amount DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'congestion_surcharge')
    ALTER TABLE stg.trip ADD congestion_surcharge DECIMAL(10,2) NULL;

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'airport_fee')
    ALTER TABLE stg.trip ADD airport_fee DECIMAL(10,2) NULL;

  -- Audit columns with defaults when adding to an existing table
  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'ingest_date')
    ALTER TABLE stg.trip ADD ingest_date DATE NOT NULL
      CONSTRAINT DF_stg_trip_ingest_date DEFAULT ('1900-01-01');

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'source_file_name')
    ALTER TABLE stg.trip ADD source_file_name NVARCHAR(512) NOT NULL
      CONSTRAINT DF_stg_trip_srcfile DEFAULT (N'');

  IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'stg.trip') AND name=N'loaded_at')
    ALTER TABLE stg.trip ADD loaded_at DATETIME2(3) NOT NULL
      CONSTRAINT DF_stg_trip_loaded_at DEFAULT (SYSUTCDATETIME());
END
GO
