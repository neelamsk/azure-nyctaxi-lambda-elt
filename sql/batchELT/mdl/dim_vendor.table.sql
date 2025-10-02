IF OBJECT_ID('mdl.dim_vendor') IS NULL
BEGIN
  CREATE TABLE mdl.dim_vendor
  (
    vendor_key       INT IDENTITY(1,1) NOT NULL,
    vendor_code_nk   VARCHAR(32)  NOT NULL,
    vendor_name      NVARCHAR(128) NULL,
    active_flag      BIT          NOT NULL DEFAULT 1,
    valid_from_utc   DATETIME2    NULL,
    valid_to_utc     DATETIME2    NULL,
    CONSTRAINT PK_dim_vendor PRIMARY KEY NONCLUSTERED (vendor_key) NOT ENFORCED
  )
  WITH (DISTRIBUTION = REPLICATE, HEAP);
END;
