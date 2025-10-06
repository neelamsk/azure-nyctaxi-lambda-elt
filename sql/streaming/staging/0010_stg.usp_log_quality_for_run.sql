IF OBJECT_ID('stg.usp_log_quality_for_run', 'P') IS NOT NULL
  DROP PROCEDURE stg.usp_log_quality_for_run;
GO

CREATE PROCEDURE stg.usp_log_quality_for_run
  @runId     NVARCHAR(50),
  @hourPath  NVARCHAR(16)  -- 'yyyy/MM/dd/HH'
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @good BIGINT = 0,
          @dlq  BIGINT = 0,
          @miss BIGINT = 0,
          @neg  BIGINT = 0,
          @bad  BIGINT = 0,
          @now  DATETIME2(3) = SYSUTCDATETIME();

  -- good rows in slice for this run
  SELECT @good = COUNT(*) 
  FROM core.trip_clean_slice 
  WHERE _runId = @runId;

  -- dlq rows for this run
  SELECT @dlq = COUNT(*) 
  FROM stg.TripsStreaming_Dlq
  WHERE _runId = @runId;

  -- reason breakdown
  SELECT
    @miss = SUM(CASE WHEN COALESCE(reason,'') = 'missing_required' THEN 1 ELSE 0 END),
    @neg  = SUM(CASE WHEN COALESCE(reason,'') = 'negative_values'  THEN 1 ELSE 0 END),
    @bad  = SUM(CASE WHEN COALESCE(reason,'') = 'bad_duration'     THEN 1 ELSE 0 END)
  FROM stg.TripsStreaming_Dlq
  WHERE _runId = @runId;

  -- persist counters
  INSERT INTO stg.TripsStreaming_Quality_Audit
    (runId, hourPath, good_rows, dlq_rows, missing_required, negative_values, bad_duration, createdAt)
  VALUES
    (@runId, @hourPath, @good, @dlq, @miss, @neg, @bad, @now);

  -- emit one-row result set (handy in ADF Script outputs)
  SELECT
    @runId   AS runId,
    @hourPath AS hourPath,
    @good    AS good_rows,
    @dlq     AS dlq_rows,
    @miss    AS missing_required,
    @neg     AS negative_values,
    @bad     AS bad_duration;

  -- optional: log via existing ingest logger
  DECLARE @msg NVARCHAR(4000) =
    N'{"kind":"dq","good_rows":' + CONVERT(NVARCHAR(30),@good) +
    N',"dlq_rows":' + CONVERT(NVARCHAR(30),@dlq) +
    N',"missing_required":' + CONVERT(NVARCHAR(30),@miss) +
    N',"negative_values":' + CONVERT(NVARCHAR(30),@neg) +
    N',"bad_duration":' + CONVERT(NVARCHAR(30),@bad) + N'}';

  DECLARE @blobPath NVARCHAR(4000) = N'dq:' + @hourPath;  -- precompute (no expressions in EXEC params)

  EXEC stg.usp_log_ingest
    @runId      = @runId,
    @blobPath   = @blobPath,
    @rowsCopied = @good,
    @status     = N'DQ',
    @message    = @msg;
END
GO
