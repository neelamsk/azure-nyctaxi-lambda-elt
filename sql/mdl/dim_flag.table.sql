IF OBJECT_ID('mdl.dim_flag') IS NULL
BEGIN
  CREATE TABLE mdl.dim_flag
  (
    flag_key   INT IDENTITY(1,1) NOT NULL,
    flag_nk    VARCHAR(8) NOT NULL,   -- e.g., 'Y'/'N'
    meaning    NVARCHAR(128) NULL,
    CONSTRAINT PK_dim_flag PRIMARY KEY NONCLUSTERED (flag_key) NOT ENFORCED
  )
  WITH (DISTRIBUTION = REPLICATE, HEAP);
END;
