
-- Final body (no default on @message; set createdAt explicitly)
ALTER PROCEDURE stg.usp_log_ingest
    @runId NVARCHAR(200),
    @blobPath NVARCHAR(4000),
    @rowsCopied BIGINT,
    @status NVARCHAR(20),
    @message NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO stg.TripsStreaming_Ingest_Audit
        (runId, blobPath, rowsCopied, status, message, createdAt)
    VALUES
        (@runId, @blobPath, @rowsCopied, @status, COALESCE(@message, N''), SYSUTCDATETIME());
END
GO