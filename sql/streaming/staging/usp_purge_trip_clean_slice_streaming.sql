SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[core].[usp_purge_trip_clean_slice_streaming]', 'P') IS NOT NULL
  DROP PROCEDURE [core].[usp_purge_trip_clean_slice_streaming];
GO

CREATE PROCEDURE [core].[usp_purge_trip_clean_slice_streaming]
  @runId   NVARCHAR(50),
  @deleted INT OUTPUT
AS
BEGIN
  SET NOCOUNT ON;

  SELECT @deleted = COUNT(*) 
  FROM core.trip_clean_slice 
  WHERE _runId = @runId;

  DELETE FROM core.trip_clean_slice
  WHERE _runId = @runId;

  -- Optional: handy if you call via Script activity
  SELECT Deleted = @deleted;
END
GO

IF NOT EXISTS (
  SELECT 1
  FROM sys.indexes
  WHERE name = 'IX_trip_clean_slice__runId'
    AND object_id = OBJECT_ID('core.trip_clean_slice')
)
  CREATE NONCLUSTERED INDEX IX_trip_clean_slice__runId
  ON core.trip_clean_slice (_runId);