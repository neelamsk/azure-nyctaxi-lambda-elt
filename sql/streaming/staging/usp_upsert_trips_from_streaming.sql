ALTER PROCEDURE core.usp_build_trip_clean_slice_streaming
    @runId NVARCHAR(50)
AS
BEGIN
  SET NOCOUNT ON;

  DELETE FROM core.trip_clean_slice WHERE _runId = @runId;

  ;WITH base AS
  (
    SELECT
      s.*,
      -- Natural key text (eventId may be NULL)
      CONCAT(ISNULL(CAST(s.eventId AS NVARCHAR(200)), N''),
             N'|', CONVERT(VARCHAR(33), s.tpepPickupDatetime, 126),
             N'|', CONVERT(VARCHAR(33), s.tpepDropoffDatetime, 126)) AS trip_nk
    FROM stg.TripsStreaming AS s
    WHERE s._runId = @runId
  ),
  src AS
  (
    SELECT
      b.vendorId                                   AS vendor_code,
      ABS(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', b.trip_nk),1,8))) AS trip_id,
      b.tpepPickupDatetime                         AS pickup_ts_utc,
      b.tpepDropoffDatetime                        AS dropoff_ts_utc,
      CAST(b.tripDistance * 1.609344 AS FLOAT)     AS trip_distance_km,
      CAST(b.totalAmount AS DECIMAL(9,2))          AS fare_amount,
      CAST(b.paymentType AS VARCHAR(50))           AS payment_type,
      CASE
        WHEN DATEPART(hour, b.tpepPickupDatetime) BETWEEN 20 AND 23
          OR DATEPART(hour, b.tpepPickupDatetime) BETWEEN 0 AND 5
        THEN 1 ELSE 0
      END                                          AS is_night_ride,
      CAST(ISNULL(b._ingestedAt, SYSUTCDATETIME()) AS DATE) AS ingest_date,
      CASE
        WHEN b._blobPath IS NULL THEN 'streaming'
        ELSE RIGHT(b._blobPath, CHARINDEX('/', REVERSE(b._blobPath) + '/') - 1)
      END                                          AS source_file_name,
      SYSUTCDATETIME()                             AS loaded_at,
      b._runId, b._blobPath, b._ingestedAt,
      ROW_NUMBER() OVER (
        PARTITION BY ABS(CONVERT(BIGINT, SUBSTRING(HASHBYTES('SHA2_256', b.trip_nk),1,8)))
        ORDER BY b.producerTs DESC, b.enqueuedTs DESC
      ) AS rn
    FROM base AS b
  )
  INSERT INTO core.trip_clean_slice
  (
    vendor_code, trip_id, pickup_ts_utc, dropoff_ts_utc, trip_distance_km,
    fare_amount, payment_type, is_night_ride, ingest_date, source_file_name,
    loaded_at, _runId, _blobPath, _ingestedAt
  )
  SELECT
    vendor_code, trip_id, pickup_ts_utc, dropoff_ts_utc, trip_distance_km,
    fare_amount, payment_type, is_night_ride, ingest_date, source_file_name,
    loaded_at, _runId, _blobPath, _ingestedAt
  FROM src
  WHERE rn = 1;
END
GO
