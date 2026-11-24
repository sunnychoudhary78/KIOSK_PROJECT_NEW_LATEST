-- Run once as the postgres superuser:
--   $env:PGPASSWORD = 'YOUR_POSTGRES_PASSWORD'
--   & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -h localhost -p 5432 -f tooling/scripts/setup-local-db.sql

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'skp') THEN
    CREATE ROLE skp LOGIN PASSWORD 'skp_dev_password';
  ELSE
    ALTER ROLE skp WITH LOGIN PASSWORD 'skp_dev_password';
  END IF;
END
$$;

SELECT 'CREATE DATABASE skp_local OWNER skp'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'skp_local')\gexec

GRANT ALL PRIVILEGES ON DATABASE skp_local TO skp;
