IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'mdl')
  EXEC('CREATE SCHEMA mdl');
