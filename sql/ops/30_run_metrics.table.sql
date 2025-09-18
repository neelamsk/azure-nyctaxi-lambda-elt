IF OBJECT_ID('ops.run_metrics') IS NULL
BEGIN
  CREATE TABLE ops.run_metrics
  (
    layer           VARCHAR(16)  NOT NULL,   -- 'stg' | 'core' | 'mdl'
    table_name      VARCHAR(128) NOT NULL,
    ingest_date     DATE         NOT NULL,
    rows_in         BIGINT       NULL,
    rows_out        BIGINT       NULL,
    rows_err        BIGINT       NULL,
    run_ts_utc      DATETIME2    NOT NULL,
    recorded_at_utc DATETIME2    NULL
  )
  WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
END;
