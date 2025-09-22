IF OBJECT_ID('mdl.dim_time') IS NULL
BEGIN
  CREATE TABLE mdl.dim_time
  (
    time_key     INT       NOT NULL,  -- 0..86399
    hh24         TINYINT   NOT NULL,
    mm           TINYINT   NOT NULL,
    ss           TINYINT   NOT NULL,
    hour_bucket  VARCHAR(11) NULL,    -- e.g., '22:00-22:59'
    is_night     BIT       NOT NULL,  -- 22:00–05:59
    CONSTRAINT PK_dim_time PRIMARY KEY NONCLUSTERED (time_key) not enforced
  )
  WITH (DISTRIBUTION = REPLICATE, HEAP);
END;
