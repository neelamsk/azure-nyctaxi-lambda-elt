IF OBJECT_ID('mdl.usp_upsert_dims_from_slice_streaming','P') IS NOT NULL
    DROP PROCEDURE mdl.usp_upsert_dims_from_slice_streaming;
GO
CREATE PROCEDURE mdl.usp_upsert_dims_from_slice_streaming
    @runId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------------------------------------------
    -- Upsert VENDORs (insert missing natural keys)
    --   Assumes: mdl.dim_vendor(vendor_key IDENTITY, vendor_code NVARCHAR/VARCAHR, …)
    ----------------------------------------------------------------
    ;WITH src AS (
        SELECT DISTINCT LTRIM(RTRIM(s.vendor_code)) AS vendor_code
        FROM core.trip_clean_slice AS s
        WHERE s._runId = @runId
          AND s.vendor_code IS NOT NULL
          AND LTRIM(RTRIM(s.vendor_code)) <> ''
    )
    INSERT INTO mdl.dim_vendor (vendor_code)
    SELECT src.vendor_code
    FROM src
    LEFT JOIN mdl.dim_vendor AS d
        ON d.vendor_code = src.vendor_code
    WHERE d.vendor_code IS NULL;

    ----------------------------------------------------------------
    -- Upsert PAYMENT TYPEs
    --   Assumes: mdl.dim_payment_type(payment_type_key IDENTITY, payment_type NVARCHAR/VARCAHR, …)
    ----------------------------------------------------------------
    ;WITH src AS (
        SELECT DISTINCT LTRIM(RTRIM(s.payment_type)) AS payment_type
        FROM core.trip_clean_slice AS s
        WHERE s._runId = @runId
          AND s.payment_type IS NOT NULL
          AND LTRIM(RTRIM(s.payment_type)) <> ''
    )
    INSERT INTO mdl.dim_payment_type (payment_type)
    SELECT src.payment_type
    FROM src
    LEFT JOIN mdl.dim_payment_type AS d
        ON d.payment_type = src.payment_type
    WHERE d.payment_type IS NULL;

       -- LOCATION
       ;WITH src AS (
           SELECT DISTINCT s.pu_location_id AS location_code
           FROM core.trip_clean_slice s
           WHERE s._runId = @runId AND s.pu_location_id IS NOT NULL
       )
       INSERT INTO mdl.dim_location (location_code)
       SELECT src.location_code
       FROM src LEFT JOIN mdl.dim_location d
         ON d.location_code = src.location_code
       WHERE d.location_code IS NULL;

END
GO
