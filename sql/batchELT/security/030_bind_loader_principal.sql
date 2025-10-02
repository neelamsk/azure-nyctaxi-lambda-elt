-- Variables passed at deploy time:
--   :setvar ADF_PRINCIPAL "eltazr3-adf"   -- or an Entra group like 'dp-adf-loaders-dev'
-- If you prefer objectId: use the GUID as the username string.

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '$(ADF_PRINCIPAL)')
    CREATE USER [$(ADF_PRINCIPAL)] FROM EXTERNAL PROVIDER;

-- Either attach to custom role...
EXEC sp_addrolemember N'role_ingest_loader', N'$(ADF_PRINCIPAL)';

-- ...or use built-in roles if you prefer (comment one style out):
-- ALTER ROLE db_datareader ADD MEMBER [$(ADF_PRINCIPAL)];
-- ALTER ROLE db_datawriter ADD MEMBER [$(ADF_PRINCIPAL)];
-- -- Temporary while bootstrapping table creation:
-- ALTER ROLE db_ddladmin  ADD MEMBER [$(ADF_PRINCIPAL)];
