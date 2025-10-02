IF OBJECT_ID('mdl.usp_upsert_fact_trip_streaming','P') IS NOT NULL
    DROP PROCEDURE mdl.usp_upsert_fact_trip_streaming;
GO
CREATE PROCEDURE mdl.usp_upsert_fact_trip_streaming
    @runId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    /*==============================================================
      TARGET COLUMN NAMES (adjust here once if your names differ)
      ------------------------------------------------------------
      Fact table: mdl.fact_trip
        - vendor_key            INT
        - payment_type_key      INT
        - pu_location_key       INT         -- optional, keep -1 if unknown
        - do_location_key       INT         -- optional, keep -1 if unknown
        - trip_id               BIGINT or NVARCHAR (your deterministic NK)
        - pickup_ts_utc         DATETIME2
        - dropoff_ts_utc        DATETIME2
        - trip_distance_km      FLOAT/DECIMAL
        - fare_amount           DECIMAL
        - ingest_date           DATE
        - loaded_at             DATETIME2
        - source_file_name      NVARCHAR
        - _runId                NVARCHAR    -- lineage (optional)
        - _blobPath             NVARCHAR    -- lineage (optional)
        - _ingestedAt           DATETIME2   -- lineage (optional)
    ==============================================================*/

    ----------------------------------------------------------------
    -- Build the source set for MERGE (resolve surrogate keys)
    ----------------------------------------------------------------
    ;WITH slice AS (
        SELECT
            s.trip_id,
            s.vendor_code,
            s.payment_type,
            -- Optional location NKs if present in slice; else leave NULL
            CAST(NULL AS INT) AS pu_location_id,
            CAST(NULL AS INT) AS do_location_id,

            s.pickup_ts_utc,
            s.dropoff_ts_utc,
            s.trip_distance_km,
            s.fare_amount,
            s.ingest_date,
            s.loaded_at,
            s.source_file_name,
            s._runId,
            s._blobPath,
            s._ingestedAt
        FROM core.trip_clean_slice AS s
        WHERE s._runId = @runId
    ),
    resolved AS (
        SELECT
            sl.trip_id,

            -- vendor/payment SKs (default to -1 if not found)
            COALESCE(v.vendor_key, -1)       AS vendor_key,
            COALESCE(pt.payment_type_key, -1) AS payment_type_key,

            -- location SKs (optional; keep -1 if you don’t use these yet)
            CAST(-1 AS INT) AS pu_location_key,
            CAST(-1 AS INT) AS do_location_key,

            sl.pickup_ts_utc,
            sl.dropoff_ts_utc,
            sl.trip_distance_km,
            sl.fare_amount,
            sl.ingest_date,
            sl.loaded_at,
            sl.source_file_name,
            sl._runId,
            sl._blobPath,
            sl._ingestedAt
        FROM slice sl
        LEFT JOIN mdl.dim_vendor        v  ON v.vendor_code   = sl.vendor_code
        LEFT JOIN mdl.dim_payment_type  pt ON pt.payment_type = sl.payment_type

        /* If/when you populate location dims from slice:
        LEFT JOIN mdl.dim_location pu ON pu.location_code = sl.pu_location_id
        LEFT JOIN mdl.dim_location do_ ON do_.location_code = sl.do_location_id
        */
    )
    MERGE mdl.fact_trip AS tgt
    USING resolved AS src
       ON tgt.trip_id = src.trip_id
    WHEN MATCHED THEN
        UPDATE SET
            tgt.vendor_key        = src.vendor_key,
            tgt.payment_type_key  = src.payment_type_key,
            tgt.pu_location_key   = src.pu_location_key,   -- keep if column exists
            tgt.do_location_key   = src.do_location_key,   -- keep if column exists
            tgt.pickup_ts_utc     = src.pickup_ts_utc,
            tgt.dropoff_ts_utc    = src.dropoff_ts_utc,
            tgt.trip_distance_km  = src.trip_distance_km,
            tgt.fare_amount       = src.fare_amount,
            tgt.ingest_date       = src.ingest_date,
            tgt.loaded_at         = src.loaded_at,
            tgt.source_file_name  = src.source_file_name,
            -- lineage (comment out if your fact doesn’t have them)
            tgt._runId            = src._runId,
            tgt._blobPath         = src._blobPath,
            tgt._ingestedAt       = src._ingestedAt
    WHEN NOT MATCHED THEN
        INSERT (
            vendor_key,
            payment_type_key,
            pu_location_key,
            do_location_key,
            trip_id,
            pickup_ts_utc,
            dropoff_ts_utc,
            trip_distance_km,
            fare_amount,
            ingest_date,
            loaded_at,
            source_file_name,
            _runId,
            _blobPath,
            _ingestedAt
        )
        VALUES (
            src.vendor_key,
            src.payment_type_key,
            src.pu_location_key,
            src.do_location_key,
            src.trip_id,
            src.pickup_ts_utc,
            src.dropoff_ts_utc,
            src.trip_distance_km,
            src.fare_amount,
            src.ingest_date,
            src.loaded_at,
            src.source_file_name,
            src._runId,
            src._blobPath,
            src._ingestedAt
        )
    ;

    -- Optional: lightweight rowcount back to caller (ADF can log rows upserted)
    -- SELECT @@ROWCOUNT AS affected;
END
GO
