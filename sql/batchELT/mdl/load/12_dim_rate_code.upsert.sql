DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT CAST(RatecodeID AS VARCHAR(16)) AS rate_code_nk
  FROM stg.trip
  WHERE ingest_date = @d
    AND RatecodeID IS NOT NULL
)
INSERT INTO mdl.dim_rate_code (rate_code_nk)
SELECT s.rate_code_nk
FROM src s
LEFT JOIN mdl.dim_rate_code t
  ON t.rate_code_nk = s.rate_code_nk
WHERE t.rate_code_nk IS NULL;
