IF OBJECT_ID('stg.TripsStreaming_Quality_Audit', 'U') IS NULL
BEGIN
  CREATE TABLE stg.TripsStreaming_Quality_Audit
  (
    id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    runId            NVARCHAR(50)  NOT NULL,
    hourPath         NVARCHAR(16)  NOT NULL, -- yyyy/MM/dd/HH
    good_rows        BIGINT        NOT NULL,
    dlq_rows         BIGINT        NOT NULL,
    missing_required BIGINT        NOT NULL,
    negative_values  BIGINT        NOT NULL,
    bad_duration     BIGINT        NOT NULL,
    createdAt        DATETIME2(3)  NOT NULL DEFAULT SYSUTCDATETIME()
  );
END
GO
