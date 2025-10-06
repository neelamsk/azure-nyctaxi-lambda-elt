-- Create schemas if they don't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ref')  EXEC('CREATE SCHEMA ref');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')  EXEC('CREATE SCHEMA stg');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'core') EXEC('CREATE SCHEMA core');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'mdl')  EXEC('CREATE SCHEMA mdl');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'err')  EXEC('CREATE SCHEMA err');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ops')  EXEC('CREATE SCHEMA ops');
