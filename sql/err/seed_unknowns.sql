-- Seed "-1 / Unknown" members (so fact can always resolve to a surrogate).
-- You can re-run safely: use IF NOT EXISTS guards.

-- dim_vendor
IF NOT EXISTS (SELECT 1 FROM mdl.dim_vendor WHERE vendor_key = -1)
BEGIN
  SET IDENTITY_INSERT mdl.dim_vendor ON;
  INSERT INTO mdl.dim_vendor (vendor_key, vendor_code_nk, vendor_name, active_flag)
  VALUES (-1, 'UNKNOWN', 'Unknown Vendor', 0);
  SET IDENTITY_INSERT mdl.dim_vendor OFF;
END;

-- dim_payment_type
IF NOT EXISTS (SELECT 1 FROM mdl.dim_payment_type WHERE payment_type_key = -1)
BEGIN
  SET IDENTITY_INSERT mdl.dim_payment_type ON;
  INSERT INTO mdl.dim_payment_type (payment_type_key, payment_type_nk, description)
  VALUES (-1, 'UNKNOWN', 'Unknown Payment');
  SET IDENTITY_INSERT mdl.dim_payment_type OFF;
END;

-- dim_rate_code
IF NOT EXISTS (SELECT 1 FROM mdl.dim_rate_code WHERE rate_code_key = -1)
BEGIN
  SET IDENTITY_INSERT mdl.dim_rate_code ON;
  INSERT INTO mdl.dim_rate_code (rate_code_key, rate_code_nk, description)
  VALUES (-1, 'UNKNOWN', 'Unknown Rate Code');
  SET IDENTITY_INSERT mdl.dim_rate_code OFF;
END;

-- dim_flag
IF NOT EXISTS (SELECT 1 FROM mdl.dim_flag WHERE flag_key = -1)
BEGIN
  SET IDENTITY_INSERT mdl.dim_flag ON;
  INSERT INTO mdl.dim_flag (flag_key, flag_nk, meaning)
  VALUES (-1, 'UNKNOWN', 'Unknown Flag');
  SET IDENTITY_INSERT mdl.dim_flag OFF;
END;

-- dim_location
IF NOT EXISTS (SELECT 1 FROM mdl.dim_location WHERE location_key = -1)
BEGIN
  SET IDENTITY_INSERT mdl.dim_location ON;
  INSERT INTO mdl.dim_location (location_key, location_id_nk, borough, zone, service_zone)
  VALUES (-1, -1, 'Unknown', 'Unknown', 'Unknown');
  SET IDENTITY_INSERT mdl.dim_location OFF;
END;

-- dim_date (you can add a -1 row if your BI model expects one; otherwise not required)
-- dim_time (same note as above)
