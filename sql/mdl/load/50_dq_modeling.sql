DECLARE @run_id NVARCHAR(64) = '@{pipeline().RunId}';
DECLARE @stage  NVARCHAR(32) = 'core_to_mdl';
DECLARE @d      DATE         = '@{pipeline().parameters.run_date}';
DECLARE @now    DATETIME2(3) = SYSUTCDATETIME();

-- Counts
DECLARE @rows_core BIGINT = (SELECT COUNT(*) FROM core.trip_clean WHERE ingest_date=@d);
DECLARE @rows_fact BIGINT = (SELECT COUNT(*) FROM mdl.fact_trip  WHERE ingest_date=@d);

-- Unknown FK counts
DECLARE @u_vendor BIGINT = (SELECT COUNT(*) FROM mdl.fact_trip WHERE ingest_date=@d AND vendor_key = -1);
DECLARE @u_pay    BIGINT = (SELECT COUNT(*) FROM mdl.fact_trip WHERE ingest_date=@d AND payment_type_key = -1);
DECLARE @u_rate   BIGINT = (SELECT COUNT(*) FROM mdl.fact_trip WHERE ingest_date=@d AND rate_code_key = -1);
DECLARE @u_flag   BIGINT = (SELECT COUNT(*) FROM mdl.fact_trip WHERE ingest_date=@d AND flag_key = -1);
DECLARE @u_pu     BIGINT = (SELECT COUNT(*) FROM mdl.fact_trip WHERE ingest_date=@d AND pu_location_key = -1);
DECLARE @u_do     BIGINT = (SELECT COUNT(*) FROM mdl.fact_trip WHERE ingest_date=@d AND do_location_key = -1);

-- Reconciliation (exact match for now; relax if needed)
DECLARE @sum_core_fare DECIMAL(18,2) = (SELECT COALESCE(SUM(fare_amount),0) FROM core.trip_clean WHERE ingest_date=@d);
DECLARE @sum_fact_fare DECIMAL(18,2) = (SELECT COALESCE(SUM(fare_amount),0) FROM mdl.fact_trip   WHERE ingest_date=@d);

-- Clean slate for this run/date
DELETE FROM ops.dq_result WHERE run_id=@run_id AND stage=@stage AND ingest_date=@d;

-- Log outcomes
INSERT INTO ops.dq_result (run_id,stage,check_name,ingest_date,status,actual_value,threshold_value,error_message,created_at_utc)
SELECT @run_id,@stage,'rowcount_fact_eq_core',@d, CASE WHEN @rows_fact=@rows_core THEN 'PASSED' ELSE 'FAILED' END, @rows_fact-@rows_core, 0, NULL,@now
UNION ALL
SELECT @run_id,@stage,'unknown_vendor_eq_0',@d,   CASE WHEN @u_vendor=0 THEN 'PASSED' ELSE 'FAILED' END, @u_vendor, 0, NULL,@now
UNION ALL
SELECT @run_id,@stage,'unknown_payment_eq_0',@d,  CASE WHEN @u_pay=0 THEN 'PASSED' ELSE 'FAILED' END, @u_pay, 0, NULL,@now
UNION ALL
SELECT @run_id,@stage,'unknown_rate_eq_0',@d,     CASE WHEN @u_rate=0 THEN 'PASSED' ELSE 'FAILED' END, @u_rate, 0, NULL,@now
UNION ALL
SELECT @run_id,@stage,'unknown_flag_eq_0',@d,     CASE WHEN @u_flag=0 THEN 'PASSED' ELSE 'FAILED' END, @u_flag, 0, NULL,@now
UNION ALL
SELECT @run_id,@stage,'unknown_pu_eq_0',@d,       CASE WHEN @u_pu=0 THEN 'PASSED' ELSE 'FAILED' END, @u_pu, 0, NULL,@now
UNION ALL
SELECT @run_id,@stage,'unknown_do_eq_0',@d,       CASE WHEN @u_do=0 THEN 'PASSED' ELSE 'FAILED' END, @u_do, 0, NULL,@now
UNION ALL
SELECT @run_id,@stage,'sum_fare_matches_core',@d, CASE WHEN @sum_fact_fare=@sum_core_fare THEN 'PASSED' ELSE 'FAILED' END,
       CAST((@sum_fact_fare-@sum_core_fare) AS DECIMAL(18,2)), 0, NULL, @now;

-- Fail if any FAILED
IF EXISTS (
  SELECT 1 FROM ops.dq_result WHERE run_id=@run_id AND stage=@stage AND ingest_date=@d AND status='FAILED'
)
  THROW 54000, 'Modeling DQ failed: see ops.dq_result for details.', 1;
