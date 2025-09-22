IF OBJECT_ID('mdl.dim_date') IS NULL
BEGIN
  CREATE TABLE mdl.dim_date
  (
    date_key      INT        NOT NULL,  -- YYYYMMDD
    date_value    DATE       NOT NULL,
    [year]        SMALLINT   NOT NULL,
    [quarter]     TINYINT    NOT NULL,
    [month]       TINYINT    NOT NULL,
    [day]         TINYINT    NOT NULL,
    week_of_year  TINYINT    NOT NULL,
    iso_year      SMALLINT   NOT NULL,
    iso_week      TINYINT    NOT NULL,
    is_weekend    BIT        NOT NULL,
    is_holiday    BIT        NOT NULL DEFAULT 0,
    CONSTRAINT PK_dim_date PRIMARY KEY NONCLUSTERED (date_key) NOT ENFORCED
  )
  WITH (DISTRIBUTION = REPLICATE, HEAP);
END;
