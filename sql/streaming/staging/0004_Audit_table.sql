CREATE TABLE stg.TripsStreaming_Ingest_Audit
(
  auditId     BIGINT IDENTITY(1,1) NOT NULL,
  runId       NVARCHAR(200)  NOT NULL,
  blobPath    NVARCHAR(4000) NOT NULL,
  rowsCopied  BIGINT         NULL,
  status      NVARCHAR(20)   NOT NULL,  -- 'Success' | 'Failure'
  message     NVARCHAR(4000) NULL,
  createdAt   DATETIME2(3)   NOT NULL,
  CONSTRAINT PK_TripsStreaming_Ingest_Audit
    PRIMARY KEY NONCLUSTERED (auditId) NOT ENFORCED
)
WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);