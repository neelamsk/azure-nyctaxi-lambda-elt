
-- Create a minimal stub if the proc doesn't exist yet
IF OBJECT_ID(N'stg.usp_delete_trips_by_blob', N'P') IS NULL
    EXEC (N'CREATE PROCEDURE stg.usp_delete_trips_by_blob @blobPath NVARCHAR(4000) AS
           BEGIN
               SET NOCOUNT ON;
           END;');
GO

-- Now define the real body
ALTER PROCEDURE stg.usp_delete_trips_by_blob
    @blobPath NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;

    -- Idempotency delete: remove any rows previously loaded for this blob
    DELETE FROM stg.TripsStreaming
    WHERE _blobPath = @blobPath;
END
GO
