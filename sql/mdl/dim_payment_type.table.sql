IF OBJECT_ID('mdl.dim_payment_type') IS NULL
BEGIN
  CREATE TABLE mdl.dim_payment_type
  (
    payment_type_key  INT IDENTITY(1,1) NOT NULL,
    payment_type_nk   VARCHAR(32) NOT NULL,   -- CARD/CASH/NO_CHARGE/DISPUTE
    description       NVARCHAR(128) NULL,
    CONSTRAINT PK_dim_payment_type PRIMARY KEY NONCLUSTERED (payment_type_key) NOT ENFORCED
  )
  WITH (DISTRIBUTION = REPLICATE, HEAP);
END;
