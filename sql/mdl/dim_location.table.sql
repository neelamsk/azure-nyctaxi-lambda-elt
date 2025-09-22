IF OBJECT_ID('mdl.dim_location') IS NULL
BEGIN
  CREATE TABLE mdl.dim_location
  (
    location_key     INT IDENTITY(1,1) NOT NULL,
    location_id_nk   SMALLINT   NOT NULL,   -- TLC Zone ID (from stg.PU/DO LocationID)
    borough          VARCHAR(64)  NULL,
    zone             VARCHAR(128) NULL,
    service_zone     VARCHAR(64)  NULL,
    CONSTRAINT PK_dim_location PRIMARY KEY NONCLUSTERED (location_key) NOT ENFORCED
  )
  WITH (DISTRIBUTION = REPLICATE, HEAP);
END;
