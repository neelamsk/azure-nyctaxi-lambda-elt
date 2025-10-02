-- create schema if needed
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')
    EXEC ('CREATE SCHEMA ops');
GO

-- run log table (no DEFAULT expressions)
CREATE TABLE ops.run_log
(
  run_id          NVARCHAR(64)   NOT NULL,  -- pipeline().RunId
  stage           NVARCHAR(32)   NOT NULL,  -- e.g. 'raw_to_stg'
  dataset         NVARCHAR(128)  NOT NULL,
  ingest_date     DATE           NOT NULL,
  status          NVARCHAR(16)   NOT NULL,  -- STARTED|SUCCEEDED|FAILED
  rows_copied     BIGINT         NULL,
  started_at_utc  DATETIME2(3)   NOT NULL,
  finished_at_utc DATETIME2(3)   NULL,
  error_message   NVARCHAR(4000) NULL
)
WITH (HEAP, DISTRIBUTION = ROUND_ROBIN);
GO
