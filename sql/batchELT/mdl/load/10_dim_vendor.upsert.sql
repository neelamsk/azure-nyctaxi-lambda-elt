DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT UPPER(LTRIM(RTRIM(vendor_code))) AS vendor_code_nk
  FROM core.trip_clean
  WHERE ingest_date = @d
    AND vendor_code IS NOT NULL AND LTRIM(RTRIM(vendor_code)) <> ''
)
INSERT INTO mdl.dim_vendor (vendor_code_nk, active_flag, valid_from_utc)
SELECT s.vendor_code_nk, 1, SYSUTCDATETIME()
FROM src s
LEFT JOIN mdl.dim_vendor t
  ON t.vendor_code_nk = s.vendor_code_nk
WHERE t.vendor_code_nk IS NULL;
