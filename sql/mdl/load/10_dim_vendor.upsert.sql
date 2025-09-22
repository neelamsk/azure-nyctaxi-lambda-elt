DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT UPPER(LTRIM(RTRIM(vendor_code))) AS vendor_code_nk
  FROM core.trip_clean
  WHERE ingest_date = @d
    AND vendor_code IS NOT NULL AND LTRIM(RTRIM(vendor_code)) <> ''
)
MERGE mdl.dim_vendor AS tgt
USING src AS s
  ON tgt.vendor_code_nk = s.vendor_code_nk
WHEN NOT MATCHED BY TARGET THEN
  INSERT (vendor_code_nk, active_flag, valid_from_utc)
  SELECT s.vendor_code_nk, 1, SYSUTCDATETIME();
