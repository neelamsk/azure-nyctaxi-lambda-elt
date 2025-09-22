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
MERGE mdl.dim_location AS tgt
USING src AS s
  ON tgt.location_id_nk = s.location_id_nk
WHEN NOT MATCHED BY TARGET THEN
  INSERT (location_id_nk) VALUES (s.location_id_nk);
