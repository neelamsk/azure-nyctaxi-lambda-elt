DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT
         UPPER(LTRIM(RTRIM(store_and_fwd_flag))) AS flag_nk
  FROM stg.trip
  WHERE ingest_date = @d
    AND store_and_fwd_flag IS NOT NULL
    AND LTRIM(RTRIM(store_and_fwd_flag)) <> ''
)
MERGE mdl.dim_flag AS tgt
USING src AS s
  ON tgt.flag_nk = s.flag_nk
WHEN NOT MATCHED BY TARGET THEN
  INSERT (flag_nk, meaning) VALUES (s.flag_nk, NULL);
