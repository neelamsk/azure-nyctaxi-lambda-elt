IF OBJECT_ID('stg.load_log') IS NULL
BEGIN
    CREATE TABLE stg.load_log
    (
        id               BIGINT IDENTITY(1,1) PRIMARY KEY,
        pipeline_name    NVARCHAR(200),
        run_id           UNIQUEIDENTIFIER NULL,
        dataset_name     NVARCHAR(200),
        ingest_date      DATE,
        file_name        NVARCHAR(400),
        rows_copied      BIGINT,
        status           NVARCHAR(50),
        started_at       DATETIME2(3),
        finished_at      DATETIME2(3),
        error_message    NVARCHAR(2000) NULL
    );
END
