-- Error quarantine table for rejected rows (optional but recommended).
IF OBJECT_ID('err.trip') IS NULL
BEGIN
  CREATE TABLE err.trip
  (
    ingest_date        DATE          NOT NULL,
    source_file_name   VARCHAR(256)  NULL,
    loaded_at          DATETIME2     NULL,
    reject_reason      VARCHAR(64)   NOT NULL,
    raw_payload        NVARCHAR(MAX) NULL,   -- store JSON/CSV row if available
    recorded_at_utc    DATETIME2     NOT NULL 
  )
  WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
END;
