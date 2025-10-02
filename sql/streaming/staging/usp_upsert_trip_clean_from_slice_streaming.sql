IF OBJECT_ID(N'core.usp_upsert_trip_clean_from_slice_streaming', N'P') IS NULL
    EXEC (N'CREATE PROCEDURE core.usp_upsert_trip_clean_from_slice_streaming @runId NVARCHAR(50) AS BEGIN SET NOCOUNT ON; END;');
GO

ALTER PROCEDURE core.usp_upsert_trip_clean_from_slice_streaming
    @runId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    MERGE core.trip_clean AS tgt
    USING (
        SELECT
            vendor_code,
            trip_id,
            pickup_ts_utc,
            dropoff_ts_utc,
            CAST(trip_distance_km AS DECIMAL(9,3))                 AS trip_distance_km,
            fare_amount,
            LEFT(payment_type, 16)                                  AS payment_type, -- clean col is varchar(16)
            CAST(CASE WHEN is_night_ride = 1 THEN 1 ELSE 0 END AS BIT) AS is_night_ride,
            ingest_date,
            LEFT(source_file_name, 256)                             AS source_file_name,
            SYSUTCDATETIME()                                        AS loaded_at,
            _runId, _blobPath, _ingestedAt
        FROM core.trip_clean_slice
        WHERE _runId = @runId
    ) AS src
      ON tgt.trip_id = src.trip_id  -- stable, derived from eventId+times
    WHEN MATCHED THEN
      UPDATE SET
        tgt.vendor_code      = src.vendor_code,
        tgt.pickup_ts_utc    = src.pickup_ts_utc,
        tgt.dropoff_ts_utc   = src.dropoff_ts_utc,
        tgt.trip_distance_km = src.trip_distance_km,
        tgt.fare_amount      = src.fare_amount,
        tgt.payment_type     = src.payment_type,
        tgt.is_night_ridE    = src.is_night_ride,
        tgt.ingest_date      = src.ingest_date,
        tgt.source_file_name = src.source_file_name,
        tgt.loaded_at        = src.loaded_at,
        tgt._runId           = src._runId,
        tgt._blobPath        = src._blobPath,
        tgt._ingestedAt      = src._ingestedAt
    WHEN NOT MATCHED BY TARGET THEN
      INSERT
      (
        vendor_code, trip_id, pickup_ts_utc, dropoff_ts_utc, trip_distance_km,
        fare_amount, payment_type, is_night_ride, ingest_date, source_file_name,
        loaded_at, _runId, _blobPath, _ingestedAt
      )
      VALUES
      (
        src.vendor_code, src.trip_id, src.pickup_ts_utc, src.dropoff_ts_utc, src.trip_distance_km,
        src.fare_amount, src.payment_type, src.is_night_ride, src.ingest_date, src.source_file_name,
        src.loaded_at, src._runId, src._blobPath, src._ingestedAt
      );
END
GO
