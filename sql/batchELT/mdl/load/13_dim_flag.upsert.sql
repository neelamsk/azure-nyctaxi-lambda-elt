DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT UPPER(LTRIM(RTRIM(store_and_fwd_flag))) AS flag_nk
  FROM stg.trip
  WHERE ingest_date = @d
    AND store_and_fwd_flag IS NOT NULL
    AND LTRIM(RTRIM(store_and_fwd_flag)) <> ''
)
INSERT INTO mdl.dim_flag (flag_nk, meaning)
SELECT s.flag_nk, NULL
FROM src s
LEFT JOIN mdl.dim_flag t
  ON t.flag_nk = s.flag_nk
WHERE t.flag_nk IS NULL;
