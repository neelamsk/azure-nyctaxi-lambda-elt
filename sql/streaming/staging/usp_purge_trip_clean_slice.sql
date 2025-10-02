IF OBJECT_ID('core.usp_purge_trip_clean_slice','P') IS NOT NULL
    DROP PROCEDURE core.usp_purge_trip_clean_slice;
GO
CREATE PROCEDURE core.usp_purge_trip_clean_slice
    @keepDays INT   -- e.g., 14
AS
BEGIN
    SET NOCOUNT ON;

    IF @keepDays IS NULL OR @keepDays < 1
    BEGIN
        RAISERROR('keepDays must be >= 1', 16, 1);
    END
    ELSE
    BEGIN
        DECLARE @cutoffDate DATE = CONVERT(date, DATEADD(DAY, -@keepDays, SYSUTCDATETIME()));
        DECLARE @rows BIGINT;

        -- Pre-count rows to purge (Synapse-safe, avoids @@ROWCOUNT)
        SELECT @rows = COUNT(*)
        FROM core.trip_clean_slice
        WHERE ingest_date < @cutoffDate;

        DELETE FROM core.trip_clean_slice
        WHERE ingest_date < @cutoffDate;

        -- Simple summary ADF can read
        SELECT @rows AS rows_deleted, @cutoffDate AS cutoff_date;
    END
END
GO
