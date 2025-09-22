IF OBJECT_ID('mdl.dim_rate_code') IS NULL
BEGIN
  CREATE TABLE mdl.dim_rate_code
  (
    rate_code_key  INT IDENTITY(1,1) NOT NULL,
    rate_code_nk   VARCHAR(16) NOT NULL,   -- from stg.RatecodeID
    description    NVARCHAR(128) NULL,
    CONSTRAINT PK_dim_rate_code PRIMARY KEY NONCLUSTERED (rate_code_key) NOT ENFORCED
  )
  WITH (DISTRIBUTION = REPLICATE, HEAP);
END;
