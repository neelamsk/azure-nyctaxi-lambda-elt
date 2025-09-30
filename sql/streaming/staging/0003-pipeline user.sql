# Grant ADF MI rights in SQL
# Run in the target DB
# Create an AAD user for the Data Factory MI (objectId = $ADF_MI)
CREATE USER [adf-nyctaxi-stream] FROM EXTERNAL PROVIDER;  # name is cosmetic

-- Minimal perms for COPY into staging
GRANT INSERT ON SCHEMA::stg TO [adf-nyctaxi-stream];
GRANT SELECT ON SCHEMA::stg TO [adf-nyctaxi-stream];

-- If you'll run a Stored Proc step later:
GRANT EXECUTE TO [adf-nyctaxi-stream];
