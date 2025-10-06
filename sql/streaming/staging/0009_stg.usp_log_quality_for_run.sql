IF OBJECT_ID('stg.TripsStreaming_Quality_Audit', 'U') IS NULL
BEGIN
  CREATE TABLE stg.TripsStreaming_Quality_Audit
  (
    id               BIGINT IDENTITY(1,1) NOT NULL,
    runId            NVARCHAR(50)  NOT NULL,
    hourPath         NVARCHAR(16)  NOT NULL, -- yyyy/MM/dd/HH
    good_rows        BIGINT        NOT NULL,
    dlq_rows         BIGINT        NOT NULL,
    missing_required BIGINT        NOT NULL,
    negative_values  BIGINT        NOT NULL,
    bad_duration     BIGINT        NOT NULL,
    createdAt        DATETIME2(3)  NOT NULL
  )
  WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);

  -- Optional metadata-only PK label (not enforced in Synapse):
  -- ALTER TABLE stg.TripsStreaming_Quality_Audit
  --   ADD CONSTRAINT PK_Quality_Audit PRIMARY KEY NONCLUSTERED (id) NOT ENFORCED;

  CREATE INDEX IX_QualityAudit_Run_Hour  ON stg.TripsStreaming_Quality_Audit(runId, hourPath);
  CREATE INDEX IX_QualityAudit_CreatedAt ON stg.TripsStreaming_Quality_Audit(createdAt);
END;
