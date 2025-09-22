DECLARE @d DATE = '@{pipeline().parameters.run_date}';

;WITH src AS (
  SELECT DISTINCT CAST(PULocationID AS SMALLINT) AS location_id_nk
  FROM stg.trip
  WHERE ingest_date = @d AND PULocationID IS NOT NULL
  UNION
  SELECT DISTINCT CAST(DOLocationID AS SMALLINT) AS location_id_nk
  FROM stg.trip
  WHERE ingest_date = @d AND DOLocationID IS NOT NULL
)
INSERT INTO mdl.dim_location (location_id_nk)
SELECT s.location_id_nk
FROM src s
LEFT JOIN mdl.dim_location t
  ON t.location_id_nk = s.location_id_nk
WHERE t.location_id_nk IS NULL;
