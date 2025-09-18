-- Reference table for canonical payment types
IF OBJECT_ID('ref.payment_type_map') IS NULL
BEGIN
  CREATE TABLE ref.payment_type_map
  (
    payment_type_src  VARCHAR(50)  NOT NULL,  -- raw code/text from source
    payment_type_std  VARCHAR(50)  NOT NULL,  -- canonical value
    is_active         BIT          NOT NULL,
    valid_from_utc    DATETIME2    NULL,
    valid_to_utc      DATETIME2    NULL
  )
  WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
END;


-- Example seeds (edit to your dataset)
;WITH seed AS (
  SELECT '1'   AS payment_type_src, 'CARD'      AS payment_type_std
  UNION ALL SELECT '2',  'CASH'
  UNION ALL SELECT '3',  'NO_CHARGE'
  UNION ALL SELECT '4',  'DISPUTE'
  UNION ALL SELECT 'CRD','CARD'
  UNION ALL SELECT 'CSH','CASH'
)
INSERT INTO ref.payment_type_map (
  payment_type_src, payment_type_std, is_active, valid_from_utc, valid_to_utc
)
SELECT s.payment_type_src, s.payment_type_std, 1, SYSUTCDATETIME(), NULL
FROM seed s
LEFT JOIN ref.payment_type_map t
  ON t.payment_type_src = s.payment_type_src AND t.is_active = 1
WHERE t.payment_type_src IS NULL;

