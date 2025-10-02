DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT UPPER(LTRIM(RTRIM(payment_type))) AS payment_type_nk
  FROM core.trip_clean
  WHERE ingest_date = @d
    AND payment_type IS NOT NULL AND LTRIM(RTRIM(payment_type)) <> ''
)
INSERT INTO mdl.dim_payment_type (payment_type_nk)
SELECT s.payment_type_nk
FROM src s
LEFT JOIN mdl.dim_payment_type t
  ON t.payment_type_nk = s.payment_type_nk
WHERE t.payment_type_nk IS NULL;
