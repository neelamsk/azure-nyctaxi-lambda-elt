DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT UPPER(LTRIM(RTRIM(payment_type))) AS payment_type_nk
  FROM core.trip_clean
  WHERE ingest_date = @d
    AND payment_type IS NOT NULL AND LTRIM(RTRIM(payment_type)) <> ''
)
MERGE mdl.dim_payment_type AS tgt
USING src AS s
  ON tgt.payment_type_nk = s.payment_type_nk
WHEN NOT MATCHED BY TARGET THEN
  INSERT (payment_type_nk) VALUES (s.payment_type_nk);
