IF OBJECT_ID('stg.TripsStreaming_Dlq', 'U') IS NULL
BEGIN
  CREATE TABLE stg.TripsStreaming_Dlq
  (
    reason           NVARCHAR(64)     NULL,
    -- minimal lineage
    ingest_date      DATE             NULL,
    source_file_name NVARCHAR(260)    NULL,
    loaded_at        DATETIME2(3)     NULL,
    _runId           NVARCHAR(50)     NULL,
    _blobPath        NVARCHAR(4000)   NULL,
    _ingestedAt      DATETIME2(3)     NULL
  );
END
GO
